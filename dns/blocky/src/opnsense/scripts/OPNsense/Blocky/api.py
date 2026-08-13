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
