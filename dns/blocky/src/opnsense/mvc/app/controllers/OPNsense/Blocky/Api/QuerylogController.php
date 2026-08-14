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
use OPNsense\Core\Backend;

/**
 * Reader for blocky's query log files.
 */
class QuerylogController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'blocky';
    protected static $internalModelClass = '\OPNsense\Blocky\Blocky';

    private function run($command, $params = [])
    {
        $output = trim((new Backend())->configdpRun('blocky ' . $command, $params));
        $result = json_decode($output, true);

        if (!is_array($result)) {
            return ['status' => 'failed', 'message' => $output === '' ? gettext('No response.') : $output];
        }

        return $result;
    }

    /**
     * The log files that are currently on disk, newest first.
     */
    public function filesAction()
    {
        return $this->run('querylogfiles');
    }

    /**
     * Paginated search, shaped for a bootgrid.
     */
    public function searchAction()
    {
        $file = (string)$this->request->get('file', null, '');
        $phrase = (string)$this->request->get('searchPhrase', null, '');
        $page = (int)$this->request->get('current', null, 1);
        $rowCount = (int)$this->request->get('rowCount', null, 50);

        $result = $this->run('querylogsearch', [$file, $phrase, $page, $rowCount]);

        if (($result['status'] ?? '') !== 'ok') {
            /* Keep the grid usable by handing it an empty result set alongside the reason. */
            return [
                'total' => 0,
                'current' => 1,
                'rowCount' => $rowCount,
                'rows' => [],
                'message' => $result['message'] ?? gettext('The query log could not be read.'),
            ];
        }

        unset($result['status']);

        return $result;
    }
}
