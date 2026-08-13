#!/bin/sh

# Create the directories blocky writes to. Run before every start so that a wiped /var is repaired
# automatically rather than turning into a startup failure. blocky refuses to start when the query
# log target does not exist.

set -e

/bin/mkdir -p /var/log/blocky/querylog
/bin/mkdir -p /var/cache/blocky/lists
/bin/mkdir -p /usr/local/etc/blocky

/bin/chmod 0750 /var/log/blocky /var/log/blocky/querylog
/bin/chmod 0750 /var/cache/blocky /var/cache/blocky/lists
/bin/chmod 0700 /usr/local/etc/blocky
