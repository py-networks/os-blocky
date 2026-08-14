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

namespace OPNsense\Blocky\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Base\UserException;
use OPNsense\Core\Backend;

/**
 * Live control of a running blocky instance.
 *
 * These operations go through blocky's REST API rather than the configuration file, so they take
 * effect immediately and are forgotten on restart. Everything that has to persist belongs in the
 * settings model instead.
 */
class BlockingController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'blocky';
    protected static $internalModelClass = '\OPNsense\Blocky\Blocky';

    /**
     * Run an api.py command through configd and hand the decoded result back to the caller.
     */
    private function apiCall($command, $params = [], $timeout = 120)
    {
        $backend = new Backend();
        $output = trim($backend->configdpRun('blocky ' . $command, $params, false, $timeout));
        $result = json_decode($output, true);

        if (!is_array($result)) {
            return ['status' => 'failed', 'message' => $output === '' ? gettext('No response.') : $output];
        }

        return $result;
    }

    private function requirePost()
    {
        if (!$this->request->isPost()) {
            throw new UserException(gettext('Only POST requests are allowed.'), gettext('Blocky'));
        }
    }

    public function statusAction()
    {
        return $this->apiCall('blockingstatus');
    }

    public function enableAction()
    {
        $this->requirePost();

        return $this->apiCall('blockingenable');
    }

    public function disableAction()
    {
        $this->requirePost();

        $duration = (string)$this->request->getPost('duration', null, '');
        $groups = (string)$this->request->getPost('groups', null, '');

        return $this->apiCall('blockingdisable', [$duration, $groups]);
    }

    public function refreshAction()
    {
        $this->requirePost();

        /* Downloading every list again can take minutes, well past the configd default. */
        return $this->apiCall('listsrefresh', [], 600);
    }

    public function flushcacheAction()
    {
        $this->requirePost();

        return $this->apiCall('cacheflush');
    }

    public function queryAction()
    {
        $this->requirePost();

        $name = (string)$this->request->getPost('name', null, '');
        $type = (string)$this->request->getPost('type', null, 'A');

        if ($name === '') {
            return ['status' => 'failed', 'message' => gettext('Enter a name to look up.')];
        }

        return $this->apiCall('query', [$name, $type]);
    }
}
