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

    Reader for blocky's query log.

    Despite the "csv" name of the setting, blocky writes tab separated records
    with no header row, one file per day named <YYYY-MM-DD>_<clients>.log.
    Fields switched off in the configuration are written as empty cells rather
    than dropped, so the layout is fixed and parsed by position.
"""

import glob
import json
import os
import sys

LOG_DIR = '/var/log/blocky/querylog'
# Safety net so that a very large day cannot exhaust memory in the web process.
MAX_MATCHES = 200000

COLUMNS = [
    'time',
    'client_ip',
    'client_name',
    'duration_ms',
    'reason',
    'question',
    'answer',
    'response_code',
    'response_type',
    'question_type',
    'instance',
]


def available_files():
    """Log files, newest first. The first ten characters of the name are the date."""
    names = [os.path.basename(path) for path in glob.glob(os.path.join(LOG_DIR, '*.log'))]

    return sorted(names, reverse=True)


def parse_line(line):
    fields = line.rstrip('\n').split('\t')
    # Tolerate both shorter rows from older versions and extra trailing columns.
    fields = (fields + [''] * len(COLUMNS))[:len(COLUMNS)]

    return dict(zip(COLUMNS, fields))


def search(filename, phrase, page, row_count):
    if not filename or '/' in filename or not filename.endswith('.log'):
        return {'status': 'failed', 'message': 'invalid log file'}

    path = os.path.join(LOG_DIR, filename)
    if not os.path.isfile(path):
        return {'status': 'failed', 'message': 'log file does not exist'}

    needle = phrase.lower()
    matches = []

    with open(path, 'r', errors='replace') as handle:
        for line in handle:
            if not line.strip():
                continue
            if needle and needle not in line.lower():
                continue
            matches.append(line)
            if len(matches) >= MAX_MATCHES:
                break

    # Newest entries are appended, so the last line is the most recent one.
    matches.reverse()
    total = len(matches)

    if row_count > 0:
        start = max(page - 1, 0) * row_count
        window = matches[start:start + row_count]
    else:
        window = matches

    return {
        'status': 'ok',
        'total': total,
        'current': page,
        'rowCount': row_count,
        'rows': [parse_line(line) for line in window],
    }


def to_int(value, fallback):
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def main():
    args = sys.argv[1:]
    command = args[0] if args else ''

    if command == 'files':
        result = {'status': 'ok', 'files': available_files()}
    elif command == 'search':
        filename = args[1] if len(args) > 1 else ''
        if filename == '':
            files = available_files()
            if not files:
                result = {'status': 'ok', 'total': 0, 'current': 1, 'rowCount': 0, 'rows': []}
                print(json.dumps(result))
                return
            filename = files[0]
        result = search(
            filename,
            args[2] if len(args) > 2 else '',
            to_int(args[3] if len(args) > 3 else '', 1),
            to_int(args[4] if len(args) > 4 else '', 50),
        )
    else:
        result = {'status': 'failed', 'message': 'unknown command'}

    print(json.dumps(result))


if __name__ == '__main__':
    main()
