#!/bin/sh

# Everything that has to happen before blocky is (re)started: render the configuration template,
# create its directories and write out the TLS material selected in the GUI.

# The GUI reconfigure path renders the template itself, but a bare "configctl blocky restart"
# (console, cron, scripts editing the model directly) does not — without this line such a restart
# silently reuses the stale /usr/local/etc/blocky-config.yml and ignores config.xml changes.
configctl template reload OPNsense/Blocky || \
	echo "Warning: template render failed, blocky will restart with the existing configuration" >&2

/usr/local/opnsense/scripts/OPNsense/Blocky/setup.sh
/usr/local/opnsense/scripts/OPNsense/Blocky/export_certs.php
