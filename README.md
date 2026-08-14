# os-blocky

An OPNsense plugin for [blocky](https://github.com/0xERR0R/blocky), a DNS proxy and ad-blocker.

Targets **OPNsense 26.7** (`FreeBSD:15:amd64`).

- **Services → Blocky → Settings** — the full blocky configuration across eleven tabs: general,
  upstreams, blocking lists, client groups, schedules, custom DNS, conditional forwarding, caching,
  query log, encrypted DNS (DoT/DoH/HTTP3) and advanced options.
- **Services → Blocky → Status** — blocking state with the auto re-enable countdown, buttons to
  enable or temporarily disable blocking, refresh lists and flush the cache, 24 hour statistics with
  charts, and a lookup test tool.
- **Services → Blocky → Query Log** — browser for blocky's per-query log files.
- **Services → Blocky → Log File** — the service log, through the standard OPNsense log viewer.
- **Dashboard widgets** — `Blocky` (service and blocking state, counters) and `Blocky Statistics`
  (allowed against blocked queries per hour).

The generated configuration is validated with `blocky validate` before the service is touched, and
blocky's unauthenticated REST API is always bound to `127.0.0.1` and proxied through the OPNsense
API.

## Installing

blocky itself is **not** in the OPNsense package repository, so it has to come from somewhere. This
project publishes both packages to a signed pkg repository on GitHub Pages.

### From the package repository (recommended)

On the firewall, as `root`:

```sh
fetch -o /usr/local/etc/pkg/keys/os-blocky.pub \
    https://py-networks.github.io/os-blocky/os-blocky.pub
fetch -o /usr/local/etc/pkg/repos/OsBlocky.conf \
    https://py-networks.github.io/os-blocky/OsBlocky.conf
pkg update
pkg install os-blocky
```

`pkg update` should report the `OsBlocky` repository as signed and trusted; if it says *unsigned*,
the public key is not where the repository configuration expects it. From then on the plugin appears
under **System → Firmware → Plugins** and upgrades with the rest of the system.

The repository is registered at priority 200. It contains only `blocky` and `os-blocky`, so it
cannot shadow an OPNsense core package, but it does outrank other third-party repositories that
also ship a `blocky` package (mimugmail's sits at 190) — pkg picks by repository priority, not by
version.

### By sideloading

Every build is also published as a GitHub release. blocky must go first — it is a dependency.

```sh
pkg add https://github.com/py-networks/os-blocky/releases/download/latest/blocky.pkg
pkg add https://github.com/py-networks/os-blocky/releases/download/latest/os-blocky.pkg
```

Note that the plugin ships a firmware hook
(`src/opnsense/scripts/firmware/repos/OsBlocky.php`) which writes
`/usr/local/etc/pkg/repos/OsBlocky.conf` and the matching public key when it is installed, and
rewrites them whenever the firmware configuration is saved. **Installing this plugin therefore
subscribes the firewall to a third-party package repository**, which is what makes upgrades work
from the GUI and what repairs the configuration after a major OPNsense upgrade. To opt out:

```sh
touch /usr/local/etc/pkg/repos/OsBlocky.conf.disabled
```

The hook then removes the repository configuration and the key, and leaves them alone from that
point on. Removing the plugin removes both files too.

### Caveats

- The plugin listens on port **5300** by default so that a fresh install cannot collide with
  Unbound. To serve the network on port 53, disable Unbound (or move it to another port) first and
  then change the listen address in the plugin settings. Nothing reconfigures Unbound for you.
- blocky has no configuration reload signal, so applying settings always restarts the service.
- **System → Firmware → Audit → Health** compares installed packages against the OPNsense
  repository, so it reports `blocky` and `os-blocky` as foreign. That is expected for any
  third-party package.

## Building from source

Building requires a FreeBSD 15.1 host. `Mk/defaults.mk` probes `/usr/local/bin/php` and
`/usr/local/bin/python3` by path, so `python3` needs a symlink, and `make style` passes vacuously
when its tools are missing. `.github/workflows/build.yml` is the authoritative, working recipe;
this is the same thing by hand:

```sh
pkg install -y git gmake go126 \
    php85 php85-phar php85-tokenizer php85-xmlwriter php85-simplexml php85-dom \
    python312 py312-pycodestyle
ln -sf /usr/local/bin/python3.12 /usr/local/bin/python3
fetch -o /usr/local/bin/phpcs \
    https://github.com/PHPCSStandards/PHP_CodeSniffer/releases/latest/download/phpcs.phar
fetch -o /usr/local/bin/phpcbf \
    https://github.com/PHPCSStandards/PHP_CodeSniffer/releases/latest/download/phpcbf.phar
chmod +x /usr/local/bin/phpcs /usr/local/bin/phpcbf
```

`Mk/lint.mk`, `style.mk` and `sweep.mk` include `${PLUGINSDIR}/../core/Mk/*.mk`, so a checkout of
[opnsense/core](https://github.com/opnsense/core) must exist as a **sibling** of this repository:

```sh
git clone --depth 1 -b stable/26.7 https://github.com/opnsense/core ../core
```

blocky is built from the vendored port in `ports/dns/blocky/`, which needs only the ports
*framework*, not the whole tree:

```sh
git clone --depth 1 --filter=blob:none --no-checkout https://github.com/opnsense/ports /usr/ports
cd /usr/ports
git sparse-checkout set --no-cone Mk Keywords Templates Tools GIDs UIDs
git checkout
cp -R <this repo>/ports/dns/blocky /usr/ports/dns/blocky
make -C /usr/ports/dns/blocky makesum package
pkg add /usr/ports/dns/blocky/work/pkg/blocky-*.pkg
```

blocky has to be *installed* before the plugin is packaged, because `plugins.mk`'s `manifest` target
runs `pkg query` against every `PLUGIN_DEPENDS` entry. Then:

```sh
make -C dns/blocky lint style
make -C dns/blocky package     # -> dns/blocky/work/pkg/os-blocky-1.0.pkg
```

## Repository layout

```
Mk/  Scripts/  Templates/    vendored from opnsense/plugins @ stable/26.7
dns/blocky/                  the plugin itself
ports/dns/blocky/            vendored FreeBSD port for the blocky dependency
site/                        static content for the GitHub Pages package repository
.github/workflows/           FreeBSD build, publish, and the upstream version watcher
```

The plugin directory mirrors the layout of
[opnsense/plugins](https://github.com/opnsense/plugins) so that `Mk/plugins.mk` resolves
`PLUGINSDIR` correctly, the package lands in the `dns` category, and the plugin could be contributed
upstream as a plain directory move.

The vendored build files come from opnsense/plugins commit
`db3b854ab7e431061d911b887e6d7f1551b5a8f4` (branch `stable/26.7`). Refresh them with:

```sh
ssh root@<buildhost> 'cd /usr/plugins && tar -cf - Mk Scripts Templates' | tar -xf -
```

## How releases work

| Trigger | What happens |
| --- | --- |
| Push to `main` | FreeBSD build, lint, style; publishes to the pkg repository and refreshes the rolling `latest` release. |
| Pull request | Same build, lint and style, publishing nothing. |
| Push of a `v*` tag | Same as a `main` push, plus an immutable tagged release. |
| Daily at 06:00 UTC | `blocky-update.yml` compares `DISTVERSION` in `ports/dns/blocky/Makefile` against the newest upstream blocky release. Only a real, forward-moving version change bumps the port and triggers a build. |

The plugin's package version is `PLUGIN_VERSION` from `dns/blocky/Makefile` plus a `PORTREVISION`
taken from the commit count, so every push to `main` produces a version `pkg` considers newer
without hand-editing the Makefile. Bumping `PLUGIN_VERSION` still wins over any accumulated
revision.

## License

BSD 2-Clause. See [LICENSE](LICENSE).
