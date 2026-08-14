#!/usr/local/bin/php
<?php

/*
 * Copyright (C) 2026 pyarmak <pyarmak@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Registers the os-blocky package repository so that the plugin and the blocky package it depends
 * on can be upgraded through Firmware -> Plugins like any other plugin. OPNsense runs every
 * executable in this directory on install and whenever the firmware configuration is written, which
 * makes the repository configuration self-healing across major upgrades.
 *
 * Create /usr/local/etc/pkg/repos/OsBlocky.conf.disabled to opt out; this script then leaves the
 * repository configuration alone and removes any it previously wrote.
 */

$repo_dir = '/usr/local/etc/pkg/repos';
$keys_dir = '/usr/local/etc/pkg/keys';

$repo_file = "{$repo_dir}/OsBlocky.conf";
$key_file = "{$keys_dir}/os-blocky.pub";
$optout_file = "{$repo_file}.disabled";

/* The public key is inlined rather than shipped alongside because plugins.mk turns every file in
   this directory into an executable line of the package's +POST_INSTALL script. */
$public_key = <<<'EOKEY'
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA7oc2YPcwPGezfu5fb6wa
QBNLX/5+gf58ZJy9F+ZuLz301bMysxRQ7zRjZneJUUcmDeo++Pxip32W95qNMCev
IwHdSJTxXYDuRNUaXs6zxKE/OeqySLVnPvv/V+V3ASvjRhLZmWhPQgBftDUzX5Cq
i2FuEJmtJIppO0yAXUa7zVKVIwD2QnQYh1z9HfCSyuKoGINq1l+GPvVpQ6ldwOc3
DMuLTk8ipe5m2R8Bg3Ez6z1gqY8Cy4jc06kdvbmyuNp1s0yYNZ3mRUEL3Lgv9mf2
xkDTzr/mWQbxAVyaVKSPws/x3TD+spbUKL7fvEiLk99JFnzpGe6X2bIEhBH7E7ET
a7lnn5hYXMGgedZUQ1HNqMQUnoyfD7OoL8ZnaQZyHL3ZDPWo3H9mSzriq3LO5bWQ
QPt1mGUYDLr62WFpImf6xUvg2ulYnhSw0mS/Mken3GHw6dNj5gcVKjzllsluTG4X
L/tNScnTjDKYO2XAGfGZ4B93+NVw/NQeJCLAM/AulyXvc0EBpzQPyB/rNtunVdK5
Rn4IXVWE9m3GCBaQhhTY3hFAvdjD4H2hUaS43Vwik/jN7D9DuWBBqjplgfdW22jB
WZ+oXQ9ithshX+/SbbmbFKc5ji+boXtLySEyIcaAd1lEkXc3sn4DHULxBMq+Nhsm
gU+0ymUk6VfkuWjO7FIvtmMCAwEAAQ==
-----END PUBLIC KEY-----

EOKEY;

/* Priority stays below the OPNsense repository (11) so this one can never shadow a core package. */
$repo_conf = <<<EOCONF
OsBlocky: {
  url: "https://py-networks.github.io/os-blocky/pkg/26.7/latest",
  signature_type: "pubkey",
  pubkey: "{$key_file}",
  priority: 5,
  enabled: yes
}

EOCONF;

if (file_exists($optout_file)) {
    @unlink($repo_file);
    @unlink($key_file);
    exit(0);
}

/* Rewritten only when the content actually differs, so this stays quiet on every firmware save. */
foreach ([$key_file => $public_key, $repo_file => $repo_conf] as $file => $content) {
    if (file_exists($file) && file_get_contents($file) === $content) {
        continue;
    }

    @mkdir(dirname($file), 0755, true);
    file_put_contents($file, $content);
    chmod($file, 0644);
}
