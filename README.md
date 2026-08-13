# os-blocky

An OPNsense plugin for [blocky](https://github.com/0xERR0R/blocky), a DNS proxy and ad-blocker.

Targets **OPNsense 26.7** (`FreeBSD:15:amd64`).

## Repository layout

The repository mirrors the layout of [opnsense/plugins](https://github.com/opnsense/plugins) so that
`Mk/plugins.mk` resolves `PLUGINSDIR` correctly, the package lands in the `dns` category, and the
plugin can later be contributed upstream as a plain directory move.

```
Mk/  Scripts/  Templates/    vendored from opnsense/plugins @ stable/26.7
dns/blocky/                  the plugin itself
```

The vendored build files come from opnsense/plugins commit
`db3b854ab7e431061d911b887e6d7f1551b5a8f4` (branch `stable/26.7`). Refresh them with:

```
ssh root@<buildhost> 'cd /usr/plugins && tar -cf - Mk Scripts Templates' | tar -xf -
```

## Building

Building requires a FreeBSD 15.1 host with `pkg`, `git`, `php85` and `python313` (the latter two only
for the `lint` and `style` targets, which probe `/usr/local/bin/php` and `/usr/local/bin/python3`).
A checkout of [opnsense/core](https://github.com/opnsense/core) must exist as a **sibling** of this
repository, because `Mk/lint.mk`, `style.mk` and `sweep.mk` include `${PLUGINSDIR}/../core/Mk/*.mk`.

```
make -C dns/blocky package     # -> dns/blocky/work/pkg/os-blocky-1.0.pkg
make -C dns/blocky lint style  # requires the sibling core checkout
make -C dns/blocky upgrade     # build and install on the local machine
```

## Installing

blocky itself is **not** in the OPNsense package repository, so the dependency must be provided
manually. Build it from the ports tree on a FreeBSD 15.1 machine and install the result on both the
build host and the firewall:

```
make -C /usr/ports/dns/blocky package
pkg add blocky-<version>.pkg
pkg add os-blocky-1.0.pkg
```

## Notes

- The plugin defaults to listening on port **5300** so that it does not collide with Unbound on a
  fresh install. To have blocky serve the network on port 53, disable Unbound (or move it to another
  port) first and then change the listen address in the plugin settings.
- blocky has no configuration reload signal, so applying settings always restarts the service. The
  generated configuration is validated with `blocky validate` before the service is touched.
- blocky's REST API is unauthenticated, so the plugin always binds it to `127.0.0.1` and proxies it
  through the OPNsense API.
