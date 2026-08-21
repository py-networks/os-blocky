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

    These files are also the only durable record of what blocky did. Its own
    statistics live in memory, cover a rolling 24 hours and start again from
    nothing at every restart, so anything that wants a longer or a restart-proof
    history has to be counted back out of the log. That is what "history" below
    does.
"""

import datetime
import glob
import json
import os
import sys

LOG_DIR = '/var/log/blocky/querylog'
# Safety net so that a very large day cannot exhaust memory in the web process.
MAX_MATCHES = 200000
# A day is roughly 13 MB here, and every one of them is read start to finish to be counted. The cap
# keeps the worst case within the time a web request may reasonably take, whatever retention is set.
MAX_HISTORY_DAYS = 31
DEFAULT_HISTORY_DAYS = 7
# Timestamps are written in the firewall's local time, and an hour bucket is the first 13 characters
# of one: "2026-08-20 19".
HOUR_KEY_LENGTH = 13
HOUR_KEY_FORMAT = '%Y-%m-%d %H'
HOUR_SECONDS = 3600

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


COUNTERS = ('queries', 'blocked', 'cached', 'resolved', 'filtered', 'errors')

# blocky's response type, as written in column nine, mapped to the counter it belongs to. CUSTOMDNS
# and SPECIAL have no counter of their own; they are still queries, which is why "allowed" has to be
# derived as queries - blocked - filtered rather than read off any single column.
RESPONSE_COUNTERS = {
    'BLOCKED': 'blocked',
    'CACHED': 'cached',
    'RESOLVED': 'resolved',
    'FILTERED': 'filtered',
}


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


def new_bucket():
    return dict.fromkeys(COUNTERS, 0)


def count_file(path, buckets):
    with open(path, 'r', errors='replace') as handle:
        for line in handle:
            # Anything that does not open with a date is a truncated or partly written record.
            if len(line) < HOUR_KEY_LENGTH or line[4] != '-' or line[7] != '-':
                continue

            bucket = buckets.get(line[:HOUR_KEY_LENGTH])
            if bucket is None:
                bucket = buckets[line[:HOUR_KEY_LENGTH]] = new_bucket()

            bucket['queries'] += 1

            fields = line.split('\t')
            if len(fields) > 8:
                counter = RESPONSE_COUNTERS.get(fields[8])
                if counter is not None:
                    bucket[counter] += 1
            if len(fields) > 7 and fields[7] == 'SERVFAIL':
                bucket['errors'] += 1


def local_hour(epoch):
    """RFC 3339 with the firewall's offset, so that a consumer never has to guess the zone."""
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).astimezone().isoformat()


def history(days):
    """Hourly totals over the last <days> log files, oldest bucket first.

    Buckets are keyed by epoch rather than by the local string they were counted
    under, which is what keeps the gap filling below correct across a daylight
    saving change.
    """
    # A caller that does not ask for a range gets the default rather than a single day, so that
    # /history and /history?days=0 mean the same thing.
    days = DEFAULT_HISTORY_DAYS if days <= 0 else min(days, MAX_HISTORY_DAYS)
    files = available_files()[:days]
    buckets = {}

    for name in files:
        try:
            count_file(os.path.join(LOG_DIR, name), buckets)
        except OSError:
            # blocky rolls the log over at midnight and prunes past its retention, so a file listed
            # a moment ago may already be gone. A missing day is a gap, not a failure.
            continue

    by_epoch = {}
    for key, bucket in buckets.items():
        try:
            when = datetime.datetime.strptime(key, HOUR_KEY_FORMAT)
        except ValueError:
            continue
        by_epoch[int(when.astimezone().timestamp())] = bucket

    rows = []
    if by_epoch:
        # An hour in which blocky answered nothing writes no line at all, and a chart reads a
        # missing point very differently from a zero. Fill the run in.
        for epoch in range(min(by_epoch), max(by_epoch) + HOUR_SECONDS, HOUR_SECONDS):
            bucket = by_epoch.get(epoch, new_bucket())
            rows.append(dict(bucket, hour=local_hour(epoch)))

    return {
        'status': 'ok',
        'days': len(files),
        'files': files,
        'buckets': rows,
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
    elif command == 'history':
        result = history(to_int(args[1] if len(args) > 1 else '', DEFAULT_HISTORY_DAYS))
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
