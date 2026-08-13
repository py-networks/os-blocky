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

namespace OPNsense\Blocky;

use OPNsense\Base\BaseModel;
use OPNsense\Base\Messages\Message;
use OPNsense\Core\Config;

/**
 * Blocky settings model.
 */
class Blocky extends BaseModel
{
    /**
     * Ports on which the built-in resolvers listen, so that we can warn about a collision before
     * blocky fails to bind. Returns a list of port numbers currently claimed by another service.
     */
    private function reservedDnsPorts()
    {
        $reserved = [];
        $config = Config::getInstance()->object();

        /* Unbound listens on 53 unless a port is configured explicitly. */
        if (empty($config->unbound->enable) === false) {
            $reserved[] = empty($config->unbound->port) ? '53' : (string)$config->unbound->port;
        }

        /* Dnsmasq shares the same convention. */
        if (empty($config->dnsmasq->enable) === false) {
            $reserved[] = empty($config->dnsmasq->port) ? '53' : (string)$config->dnsmasq->port;
        }

        return $reserved;
    }

    /**
     * Extract the port from a blocky listen specification, which may be a bare port ("53"),
     * a port with a leading colon (":53"), or an address and port ("127.0.0.1:53", "[::1]:53").
     */
    private function portFromListenSpec($spec)
    {
        $spec = trim($spec);
        $pos = strrpos($spec, ':');

        return $pos === false ? $spec : substr($spec, $pos + 1);
    }

    public function performValidation($validateFullModel = false)
    {
        $messages = parent::performValidation($validateFullModel);

        if ($validateFullModel || $this->general->listen_address->isFieldChanged()) {
            $reserved = $this->reservedDnsPorts();
            foreach (explode(',', (string)$this->general->listen_address) as $spec) {
                if ($spec === '') {
                    continue;
                }
                if (in_array($this->portFromListenSpec($spec), $reserved)) {
                    $messages->appendMessage(new Message(
                        gettext(
                            'This port is already used by Unbound or Dnsmasq. Disable that service ' .
                            'or move it to another port before letting blocky bind here.'
                        ),
                        $this->general->listen_address->__reference
                    ));
                    break;
                }
            }
        }

        /* blocky requires a "default" upstream group, otherwise it refuses to start. */
        if ($validateFullModel || $this->upstreams->upstream->isFieldChanged()) {
            $has_default = false;
            foreach ($this->upstreams->upstream->iterateItems() as $upstream) {
                if ((string)$upstream->enabled === '1' && (string)$upstream->group === 'default') {
                    $has_default = true;
                    break;
                }
            }
            if (!$has_default && (string)$this->general->enabled === '1') {
                $messages->appendMessage(new Message(
                    gettext('At least one enabled upstream in the group "default" is required.'),
                    $this->upstreams->upstream->__reference
                ));
            }
        }

        /*
         * blocky only activates blocking for clients listed in clientGroupsBlock. A deny list in a
         * group nothing subscribes to is downloaded and then silently ignored, which is a confusing
         * way to find out that nothing is being blocked.
         */
        if ($validateFullModel || $this->blocking->denylist->isFieldChanged()) {
            $subscribed = [];
            foreach ($this->clientgroups->clientgroup->iterateItems() as $clientgroup) {
                if ((string)$clientgroup->enabled !== '1') {
                    continue;
                }
                foreach (explode(',', (string)$clientgroup->groups) as $group) {
                    $subscribed[] = trim($group);
                }
            }

            foreach ($this->blocking->denylist->iterateItems() as $uuid => $denylist) {
                if ((string)$denylist->enabled !== '1') {
                    continue;
                }
                if (!in_array((string)$denylist->group, $subscribed)) {
                    $messages->appendMessage(new Message(
                        gettext(
                            'No client group uses this list group, so this list is downloaded but ' .
                            'never applied. Add it to a client on the Client Groups tab.'
                        ),
                        $denylist->group->__reference
                    ));
                }
            }
        }

        return $messages;
    }
}
