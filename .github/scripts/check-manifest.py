#!/usr/bin/env python3

"""Refuse to publish a package OPNsense 26.7 cannot install.

OPNsense 26.7 ships pkg 2.3.1. FreeBSD's current pkg writes each "files" entry of +MANIFEST as an
object -- {"sum": "2$...", "uname": ..., "perm": ...} -- and pkg 2.3.1 does not know that schema.
It parses such a package without complaint (only `pkg -d` reveals "Skipping unknown key for
file(...): sum"), leaves every checksum NULL, and then dereferences the NULL while deciding whether
to preserve an existing file, so the install dies on SIGSEGV part way through. Where it happens to
survive, it registers the package with no checksums at all, which quietly disables `pkg check` and
leaves the next upgrade to hit the same NULL.

The build pins pkg to the version the firewall runs so this cannot happen. This is the gate that
proves the pin actually took effect before anything reaches the package repository.
"""

import json
import subprocess
import sys

# "1$<sha256 hex>" -- the only form pkg 2.3.1 both writes and reads.
CLASSIC_PREFIX = '1$'


def manifest_of(package):
    raw = subprocess.run(
        ['tar', '-xOf', package, '+MANIFEST'],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    return json.loads(raw)


def check(package):
    files = manifest_of(package).get('files', {})

    if not files:
        print('%s: no file entries in +MANIFEST' % package, file=sys.stderr)
        return False

    bad = [name for name, entry in files.items()
           if not isinstance(entry, str) or not entry.startswith(CLASSIC_PREFIX)]

    if bad:
        print('%s: %d of %d file entries are not classic "%s<sha256>" checksums'
              % (package, len(bad), len(files), CLASSIC_PREFIX), file=sys.stderr)
        for name in sorted(bad)[:3]:
            print('    %s -> %r' % (name, files[name]), file=sys.stderr)
        print('  pkg 2.3.1 on OPNsense 26.7 cannot read these and segfaults on install.',
              file=sys.stderr)
        print('  The pkg pin in the workflow prepare step is not in effect.', file=sys.stderr)
        return False

    print('%s: %d file entries, all classic checksums' % (package, len(files)))
    return True


def main():
    packages = sys.argv[1:]

    if not packages:
        print('usage: check-manifest.py <package.pkg>...', file=sys.stderr)
        return 2

    return 0 if all([check(package) for package in packages]) else 1


if __name__ == '__main__':
    sys.exit(main())
