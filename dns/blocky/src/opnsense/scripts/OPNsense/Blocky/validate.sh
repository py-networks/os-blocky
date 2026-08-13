#!/bin/sh

# Check the generated configuration with blocky's own parser. Prints OK when the file is valid,
# otherwise the parser output, which names the offending key.

CONFIG=/usr/local/etc/blocky-config.yml

if [ ! -f "${CONFIG}" ]; then
	echo "Configuration file ${CONFIG} does not exist, apply the settings first."
	exit 0
fi

if output=$(/usr/local/sbin/blocky validate -c "${CONFIG}" 2>&1); then
	echo "OK"
else
	echo "${output}"
fi
