#!/bin/sh

# Everything that has to happen before blocky is (re)started: create its directories and write out
# the TLS material selected in the GUI.

/usr/local/opnsense/scripts/OPNsense/Blocky/setup.sh
/usr/local/opnsense/scripts/OPNsense/Blocky/export_certs.php
