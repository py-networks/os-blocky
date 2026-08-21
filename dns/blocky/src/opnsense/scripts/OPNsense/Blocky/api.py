#!/usr/local/bin/python3

"""
    Copyright (c) 2026 pyarmak <pyarmak@gmail.com>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice,
       this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.

    --------------------------------------------------------------------------

    Thin client for blocky's REST API. Always prints a JSON object so that the
    calling controller can decode it without special casing failures.

    The Prometheus endpoint is the one exception to "blocky speaks JSON": it
    answers in the text exposition format, so it is parsed here rather than
    handed on verbatim. That keeps the whole surface of this script decodable
    by the controller, and spares every consumer its own parser.
"""

import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

CONFIG_FILE = '/usr/local/etc/blocky-config.yml'
DEFAULT_ENDPOINT = '127.0.0.1:4000'
# Refreshing every list can take minutes on a slow provider.
TIMEOUT_SLOW = 300
TIMEOUT_FAST = 15

# One label pair of the Prometheus text format. Splitting the label set on commas would corrupt
# values that contain one themselves, and blocky writes several -- reason="BLOCKED (core, security)".
LABEL_PAIR = re.compile(r'([a-zA-Z_][a-zA-Z0-9_]*)="((?:[^"\\]|\\.)*)"')
# Escapes are undone in a single pass; doing it as successive replacements would turn a literal
# backslash followed by "n" into a newline.
LABEL_ESCAPE = re.compile(r'\\(.)')
LABEL_UNESCAPED = {'n': '\n', '"': '"', '\\': '\\'}
# Histogram buckets are one series per boundary and are of no use without a Prometheus server to
# aggregate them. The _count and _sum companions survive, which is what an average is derived from.
SKIP_SUFFIX = '_bucket'


def api_endpoint():
    """Read the API listen address out of the generated configuration.

    Taking it from the file rather than from config.xml keeps this in step with
    what the running instance is actually bound to.
    """
    try:
        with open(CONFIG_FILE, 'r') as handle:
            match = re.search(r'^\s*http:\s*"?([^"\s]+)"?\s*$', handle.read(), re.MULTILINE)
            if match:
                return match.group(1)
    except OSError:
        pass

    return DEFAULT_ENDPOINT


def call(path, method='GET', payload=None, timeout=TIMEOUT_FAST):
    url = 'http://%s%s' % (api_endpoint(), path)
    data = json.dumps(payload).encode() if payload is not None else None
    headers = {'Content-Type': 'application/json'} if data else {}
    request = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode().strip()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode().strip()
        return {'status': 'failed', 'message': detail or str(exc)}
    except (urllib.error.URLError, OSError) as exc:
        return {'status': 'failed', 'message': 'blocky is not reachable: %s' % exc}

    if not body:
        return {'status': 'ok'}

    try:
        return {'status': 'ok', 'result': json.loads(body)}
    except ValueError:
        return {'status': 'ok', 'result': body}


def parse_labels(text):
    labels = {}

    for name, value in LABEL_PAIR.findall(text):
        labels[name] = LABEL_ESCAPE.sub(
            lambda match: LABEL_UNESCAPED.get(match.group(1), match.group(1)), value)

    return labels


def parse_metrics(text):
    """Turn the Prometheus text exposition format into decodable JSON.

    Every metric becomes a list of samples, whether it carries labels or not, so
    that a consumer can read result[name][0]["value"] without first knowing
    which of the two shapes to expect.
    """
    metrics = {}

    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        head, brace, rest = line.partition('{')
        if brace:
            # The label set ends at the last brace; blocky writes no braces inside label values.
            body, _, value = rest.rpartition('}')
            name, labels = head, parse_labels(body)
        else:
            name, _, value = line.partition(' ')
            labels = {}

        name = name.strip()
        if not name or name.endswith(SKIP_SUFFIX):
            continue

        try:
            number = float(value.split()[0])
        except (IndexError, ValueError):
            continue

        # NaN and the infinities have no JSON spelling; json would emit them as bare words that a
        # strict decoder rejects, so an unusable sample is reported as null instead.
        if number != number or number in (float('inf'), float('-inf')):
            number = None
        elif number.is_integer():
            number = int(number)

        metrics.setdefault(name, []).append({'value': number, 'labels': labels})

    return metrics


def metrics():
    """blocky answers 404 here unless the Prometheus exporter is switched on."""
    result = call('/metrics')

    if result.get('status') != 'ok':
        return result

    body = result.get('result')
    if not isinstance(body, str):
        return {'status': 'failed', 'message': 'unexpected metrics response'}

    return {'status': 'ok', 'result': parse_metrics(body)}


def main():
    args = sys.argv[1:]
    command = args[0] if args else ''

    if command == 'status':
        result = call('/api/blocking/status')
    elif command == 'enable':
        result = call('/api/blocking/enable')
    elif command == 'disable':
        params = {}
        if len(args) > 1 and args[1]:
            params['duration'] = args[1]
        if len(args) > 2 and args[2]:
            params['groups'] = args[2]
        query = '?' + urllib.parse.urlencode(params) if params else ''
        result = call('/api/blocking/disable' + query)
    elif command == 'refresh':
        result = call('/api/lists/refresh', method='POST', timeout=TIMEOUT_SLOW)
    elif command == 'flush':
        result = call('/api/cache/flush', method='POST')
    elif command == 'stats':
        result = call('/api/stats')
    elif command == 'metrics':
        result = metrics()
    elif command == 'query':
        if len(args) < 2 or not args[1]:
            result = {'status': 'failed', 'message': 'no name to look up'}
        else:
            qtype = args[2] if len(args) > 2 and args[2] else 'A'
            result = call('/api/query', method='POST', payload={'query': args[1], 'type': qtype})
    else:
        result = {'status': 'failed', 'message': 'unknown command'}

    print(json.dumps(result))


if __name__ == '__main__':
    main()
