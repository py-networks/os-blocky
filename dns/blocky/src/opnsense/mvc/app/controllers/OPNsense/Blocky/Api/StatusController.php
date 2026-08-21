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
 * Read-only statistics for the status page and the dashboard widgets.
 */
class StatusController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'blocky';
    protected static $internalModelClass = '\OPNsense\Blocky\Blocky';

    /**
     * Rolling 24 hour statistics as collected by blocky itself.
     *
     * blocky answers with 503 unless statistics collection is enabled, which is reported back as a
     * failure with the reason rather than as an empty graph.
     */
    public function statsAction()
    {
        $output = trim((new Backend())->configdRun('blocky stats'));
        $result = json_decode($output, true);

        if (!is_array($result)) {
            return ['status' => 'failed', 'message' => $output === '' ? gettext('No response.') : $output];
        }

        if (($result['status'] ?? '') !== 'ok') {
            return $result;
        }

        $model = $this->getModel();
        $result['statistics_enabled'] = (string)$model->general->enable_statistics === '1';

        return $result;
    }

    /**
     * blocky's Prometheus counters, decoded into JSON.
     *
     * The exporter listens on the loopback interface only, which is deliberate -- it sits on the
     * same port as the unauthenticated control API. This is the authenticated way to read it.
     *
     * Every metric is a list of samples of the shape {"value": <number>, "labels": {...}}, so that
     * a caller can read result[name][0]["value"] without knowing in advance whether that particular
     * metric carries labels. Unlike the rolling window in statsAction, these are counters since
     * blocky started, and they begin again at zero when it restarts.
     */
    public function metricsAction()
    {
        $output = trim((new Backend())->configdRun('blocky metrics'));
        $result = json_decode($output, true);

        if (!is_array($result)) {
            return ['status' => 'failed', 'message' => $output === '' ? gettext('No response.') : $output];
        }

        /* Reported either way: a 404 from blocky is otherwise an opaque failure, and the exporter
           being switched off is by far the likeliest reason for one. */
        $result['metrics_enabled'] = (string)$this->getModel()->general->enable_metrics === '1';

        return $result;
    }

    /**
     * Hourly totals counted out of the query log, oldest bucket first.
     *
     * statsAction reports what blocky itself remembers, which is a rolling 24 hours held in memory
     * and lost on restart. This reads the same shape of series back out of the log files instead,
     * so it reaches as far as the configured retention and survives a restart -- at the cost of
     * reading every log file it covers, which is why the day count is capped.
     */
    public function historyAction()
    {
        $days = (int)$this->request->get('days', null, 0);

        /* A month of logs is minutes of reading in the worst case, well past the configd default. */
        $output = trim((new Backend())->configdpRun('blocky queryloghistory', [(string)$days], false, 300));
        $result = json_decode($output, true);

        if (!is_array($result)) {
            return ['status' => 'failed', 'message' => $output === '' ? gettext('No response.') : $output];
        }

        return $result;
    }
}
