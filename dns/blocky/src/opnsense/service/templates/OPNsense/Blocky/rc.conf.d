{#
 # The port ships its own rc script, which sends the daemon output to a flat file. We run our own
 # copy instead so that the log reaches syslog-ng and shows up in the OPNsense log viewer, and we
 # keep the port's script disabled to make sure only one of the two ever starts.
 #}
blocky_enable="NO"
{% if not helpers.empty('OPNsense.Blocky.general.enabled') %}
blocky_opn_enable="YES"
{% else %}
blocky_opn_enable="NO"
{% endif %}
blocky_opn_config="/usr/local/etc/blocky-config.yml"
