#!/bin/sh

# Create the directories blocky writes to. Run before every start so that a wiped /var is repaired
# automatically rather than turning into a startup failure.

set -e

/bin/mkdir -p /var/log/blocky
/bin/mkdir -p /var/cache/blocky/lists
/bin/chmod 0750 /var/log/blocky /var/cache/blocky /var/cache/blocky/lists
