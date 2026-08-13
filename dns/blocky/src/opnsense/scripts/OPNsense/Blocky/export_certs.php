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
 * blocky reads its TLS material from files rather than from the OPNsense trust store, so the
 * certificate selected in the GUI is written out here before the service starts.
 */

require_once('config.inc');
require_once('certs.inc');

use OPNsense\Core\Config;

const CERT_DIR = '/usr/local/etc/blocky';
const CERT_FILE = CERT_DIR . '/cert.pem';
const KEY_FILE = CERT_DIR . '/key.pem';

$config = Config::getInstance()->object();
$refid = (string)($config->OPNsense->Blocky->encryption->certificate ?? '');

if ($refid === '') {
    /* No certificate selected: blocky falls back to a self-signed one it generates itself. */
    @unlink(CERT_FILE);
    @unlink(KEY_FILE);
    exit(0);
}

foreach ($config->cert as $cert) {
    if ($refid !== (string)$cert->refid) {
        continue;
    }

    $crt = base64_decode((string)$cert->crt);
    $key = base64_decode((string)$cert->prv);

    if (empty($crt) || empty($key)) {
        fwrite(STDERR, "certificate {$refid} has no key pair\n");
        exit(1);
    }

    /* Append the issuing chain so that clients can build a path to their trust anchor. */
    if (!empty($cert->caref)) {
        $chain = ca_chain((array)$cert);
        if (!empty($chain)) {
            $crt = rtrim($crt) . "\n" . rtrim($chain) . "\n";
        }
    }

    if (!is_dir(CERT_DIR)) {
        mkdir(CERT_DIR, 0700, true);
    }

    file_put_contents(CERT_FILE, rtrim($crt) . "\n");
    file_put_contents(KEY_FILE, rtrim($key) . "\n");
    chmod(CERT_FILE, 0600);
    chmod(KEY_FILE, 0600);
    exit(0);
}

fwrite(STDERR, "certificate {$refid} not found\n");
exit(1);
