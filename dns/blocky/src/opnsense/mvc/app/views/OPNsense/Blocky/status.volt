{#
 # Copyright (C) 2026 pyarmak <pyarmak@gmail.com>
 # All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions are met:
 #
 # 1. Redistributions of source code must retain the above copyright notice,
 #    this list of conditions and the following disclaimer.
 #
 # 2. Redistributions in binary form must reproduce the above copyright
 #    notice, this list of conditions and the following disclaimer in the
 #    documentation and/or other materials provided with the distribution.
 #
 # THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 # INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 # AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 # AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 # OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 # POSSIBILITY OF SUCH DAMAGE.
 #}

<script src="{{ cache_safe('/ui/js/moment-with-locales.min.js') }}"></script>
<script src="{{ cache_safe('/ui/js/chart.umd.min.js') }}"></script>

<style>
    .blocky-tile { text-align: center; padding: 12px 6px; }
    .blocky-tile .blocky-tile-value { font-size: 24px; font-weight: 600; line-height: 1.2; }
    .blocky-tile .blocky-tile-label { text-transform: uppercase; font-size: 11px; opacity: 0.7; }
    .blocky-chart-wrapper { position: relative; height: 260px; }
    #blocky_hourly_wrapper { height: 300px; }
    .blocky-top-table td.blocky-count { text-align: right; white-space: nowrap; }
</style>

<script>
    'use strict';

    $(document).ready(function() {
        let hourlyChart = null;
        let typeChart = null;

        function esc(value) {
            return $('<div/>').text(value === null || value === undefined ? '' : value).html();
        }

        function num(value) {
            return (value || 0).toLocaleString();
        }

        function pct(value) {
            return ((value || 0) * 100).toFixed(1) + '%';
        }

        /**
         * Both the blocking and the statistics endpoints answer with {status, message} on failure.
         * Anything that is not an explicit "ok" is surfaced verbatim rather than silently ignored.
         */
        function failureMessage(data) {
            if (!data) {
                return "{{ lang._('No response from the blocky service.') }}";
            }
            if (data.status === 'ok') {
                return null;
            }
            return data.message || "{{ lang._('The blocky service is not responding.') }}";
        }

        function showNotice(message, level) {
            $('#blocky_notice')
                .removeClass('hidden alert-info alert-danger alert-success')
                .addClass('alert-' + (level || 'info'))
                .html(esc(message));
        }

        function clearNotice() {
            $('#blocky_notice').addClass('hidden');
        }

        function renderBlockingStatus(data) {
            const failure = failureMessage(data);
            if (failure !== null) {
                $('#blocking_state').html('<span class="label label-default">'
                    + "{{ lang._('Unknown') }}" + '</span>');
                showNotice(failure, 'danger');
                return;
            }
            clearNotice();

            const status = data.result || {};
            if (status.enabled) {
                $('#blocking_state').html('<span class="label label-success">'
                    + "{{ lang._('Blocking is on') }}" + '</span>');
                $('#blocking_detail').text('');
            } else {
                $('#blocking_state').html('<span class="label label-warning">'
                    + "{{ lang._('Blocking is off') }}" + '</span>');

                let detail = [];
                if (status.disabledGroups && status.disabledGroups.length) {
                    detail.push("{{ lang._('Groups') }}" + ': ' + status.disabledGroups.join(', '));
                }
                if (status.autoEnableInSec) {
                    const mins = Math.floor(status.autoEnableInSec / 60);
                    const secs = status.autoEnableInSec % 60;
                    detail.push("{{ lang._('Back on in') }}" + ' ' + mins + 'm ' + secs + 's');
                }
                $('#blocking_detail').text(detail.join(' — '));
            }
        }

        function loadBlockingStatus() {
            return ajaxGet('/api/blocky/blocking/status', {}, function(data) {
                renderBlockingStatus(data);
            });
        }

        function renderStats(data) {
            const failure = failureMessage(data);
            if (failure !== null) {
                $('#blocky_stats_error').removeClass('hidden').text(failure);
                $('#blocky_stats_body').addClass('hidden');
                return;
            }

            const stats = data.result || {};
            const summary = stats.summary || {};

            $('#blocky_stats_error').addClass('hidden');
            $('#blocky_stats_body').removeClass('hidden');

            $('#tile_queries').text(num(summary.queries));
            $('#tile_blocked').text(num(summary.blocked));
            $('#tile_blockrate').text(
                summary.queries ? pct(summary.blocked / summary.queries) : '0.0%'
            );
            $('#tile_cachehit').text(pct(summary.cacheHitRate));
            $('#tile_response').text((summary.avgResponseMs || 0).toFixed(1) + ' ms');
            $('#tile_cache_entries').text(num((stats.cache || {}).entries));

            renderHourly(stats.perHour || []);
            renderResponseTypes(stats.byResponseType || {});
            renderTop('#top_domains', stats.topDomains || []);
            renderTop('#top_blocked', stats.topBlockedDomains || []);
            renderTop('#top_clients', stats.topClients || []);
            renderLists(stats.lists || {});
        }

        function renderHourly(perHour) {
            const labels = perHour.map(function(row) {
                return moment(row.hour).format('HH:mm');
            });
            const queries = perHour.map(function(row) {
                /* "queries" counts everything, so subtract to avoid double counting in the stack */
                return Math.max((row.queries || 0) - (row.blocked || 0) - (row.filtered || 0), 0);
            });
            const blocked = perHour.map(function(row) { return row.blocked || 0; });
            const filtered = perHour.map(function(row) { return row.filtered || 0; });

            const datasets = [
                { label: "{{ lang._('Allowed') }}", data: queries, backgroundColor: '#3c8dbc' },
                { label: "{{ lang._('Blocked') }}", data: blocked, backgroundColor: '#d9534f' },
                { label: "{{ lang._('Filtered') }}", data: filtered, backgroundColor: '#f0ad4e' }
            ];

            if (hourlyChart !== null) {
                hourlyChart.data.labels = labels;
                hourlyChart.data.datasets.forEach(function(dataset, idx) {
                    dataset.data = datasets[idx].data;
                });
                hourlyChart.update();
                return;
            }

            hourlyChart = new Chart($('#blocky_hourly')[0].getContext('2d'), {
                type: 'bar',
                data: { labels: labels, datasets: datasets },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        x: { stacked: true },
                        y: { stacked: true, beginAtZero: true }
                    },
                    plugins: { legend: { position: 'bottom' } }
                }
            });
        }

        function renderResponseTypes(byType) {
            const labels = Object.keys(byType);
            const values = labels.map(function(key) { return byType[key]; });
            const palette = ['#3c8dbc', '#d9534f', '#5cb85c', '#f0ad4e', '#8e44ad',
                             '#00c0ef', '#605ca8', '#ff851b'];

            if (typeChart !== null) {
                typeChart.data.labels = labels;
                typeChart.data.datasets[0].data = values;
                typeChart.update();
                return;
            }

            typeChart = new Chart($('#blocky_types')[0].getContext('2d'), {
                type: 'doughnut',
                data: {
                    labels: labels,
                    datasets: [{ data: values, backgroundColor: palette }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { position: 'right' } }
                }
            });
        }

        function renderTop(selector, rows) {
            let body = '';
            rows.slice(0, 10).forEach(function(row) {
                body += '<tr><td>' + esc(row.name) + '</td>'
                     + '<td class="blocky-count">' + num(row.count) + '</td></tr>';
            });
            if (body === '') {
                body = '<tr><td colspan="2"><em>' + "{{ lang._('No data yet.') }}" + '</em></td></tr>';
            }
            $(selector).html(body);
        }

        function renderLists(lists) {
            let body = '';
            ['denylist', 'allowlist'].forEach(function(kind) {
                const groups = lists[kind] || {};
                Object.keys(groups).forEach(function(group) {
                    const label = kind === 'denylist'
                        ? "{{ lang._('Block list') }}" : "{{ lang._('Allow list') }}";
                    body += '<tr><td>' + esc(label) + '</td><td>' + esc(group) + '</td>'
                         + '<td class="blocky-count">' + num(groups[group]) + '</td></tr>';
                });
            });
            if (body === '') {
                body = '<tr><td colspan="3"><em>' + "{{ lang._('No lists loaded.') }}" + '</em></td></tr>';
            }
            $('#list_sizes').html(body);
        }

        function loadStats() {
            return ajaxGet('/api/blocky/status/stats', {}, function(data) {
                renderStats(data);
            });
        }

        function refreshAll() {
            loadBlockingStatus();
            loadStats();
        }

        /* action buttons */

        function runAction(button, url, payload, done) {
            const $button = $(button);
            const original = $button.html();
            $button.prop('disabled', true)
                .html('<i class="fa fa-spinner fa-spin"></i> ' + original);

            ajaxCall(url, payload || {}, function(data) {
                $button.prop('disabled', false).html(original);
                const failure = failureMessage(data);
                if (failure !== null) {
                    showNotice(failure, 'danger');
                } else if (done) {
                    done(data);
                }
                refreshAll();
            });
        }

        $('#act_enable').click(function() {
            runAction(this, '/api/blocky/blocking/enable', {}, function() {
                showNotice("{{ lang._('Blocking enabled.') }}", 'success');
            });
        });

        $('#act_disable').click(function() {
            runAction(this, '/api/blocky/blocking/disable', {
                duration: $('#disable_duration').val(),
                groups: $('#disable_groups').val()
            }, function() {
                showNotice("{{ lang._('Blocking disabled.') }}", 'success');
            });
        });

        $('#act_refresh').click(function() {
            runAction(this, '/api/blocky/blocking/refresh', {}, function() {
                showNotice("{{ lang._('Lists refreshed.') }}", 'success');
            });
        });

        $('#act_flush').click(function() {
            runAction(this, '/api/blocky/blocking/flushcache', {}, function() {
                showNotice("{{ lang._('Cache flushed.') }}", 'success');
            });
        });

        $('#act_query').click(function() {
            const $out = $('#query_result');
            $out.text("{{ lang._('Looking up...') }}");
            ajaxCall('/api/blocky/blocking/query', {
                name: $('#query_name').val(),
                type: $('#query_type').val()
            }, function(data) {
                const failure = failureMessage(data);
                if (failure !== null) {
                    $out.text(failure);
                    return;
                }
                const result = data.result || {};
                $out.text(
                    "{{ lang._('Response') }}" + ': ' + (result.response || '-') + '\n'
                    + "{{ lang._('Reason') }}" + ': ' + (result.reason || '-') + '\n'
                    + "{{ lang._('Response type') }}" + ': ' + (result.responseType || '-') + '\n'
                    + "{{ lang._('Return code') }}" + ': ' + (result.returnCode || '-')
                );
            });
        });

        $('#act_reload').click(function() {
            refreshAll();
        });

        updateServiceControlUI('blocky');
        refreshAll();
        setInterval(refreshAll, 30000);
    });
</script>

<div id="blocky_notice" class="alert alert-info hidden" role="alert"></div>

<div class="content-box" style="padding-bottom: 1.5em;">
    <div class="content-box-main">
        <h3>{{ lang._('Blocking') }}</h3>
        <p>
            <span id="blocking_state"></span>
            <small id="blocking_detail" style="margin-left: 8px;"></small>
        </p>
        <div class="form-inline">
            <button class="btn btn-primary" id="act_enable" type="button">
                <i class="fa fa-play fa-fw"></i> {{ lang._('Enable blocking') }}
            </button>
            <button class="btn btn-default" id="act_disable" type="button">
                <i class="fa fa-pause fa-fw"></i> {{ lang._('Disable blocking') }}
            </button>
            <input type="text" class="form-control" id="disable_duration" size="8"
                   placeholder="{{ lang._('5m') }}"
                   title="{{ lang._('How long blocking stays off. Leave empty to disable it until it is switched back on.') }}"/>
            <input type="text" class="form-control" id="disable_groups" size="20"
                   placeholder="{{ lang._('all groups') }}"
                   title="{{ lang._('Comma separated list groups to disable. Leave empty for all of them.') }}"/>
        </div>
        <hr/>
        <button class="btn btn-default" id="act_refresh" type="button">
            <i class="fa fa-refresh fa-fw"></i> {{ lang._('Refresh lists') }}
        </button>
        <button class="btn btn-default" id="act_flush" type="button">
            <i class="fa fa-eraser fa-fw"></i> {{ lang._('Flush cache') }}
        </button>
        <button class="btn btn-default" id="act_reload" type="button">
            <i class="fa fa-repeat fa-fw"></i> {{ lang._('Reload statistics') }}
        </button>
    </div>
</div>

<div class="alert alert-warning hidden" id="blocky_stats_error" role="alert"></div>

<div id="blocky_stats_body" class="hidden">
    <div class="content-box" style="margin-top: 1em;">
        <div class="row">
            <div class="col-sm-2 blocky-tile">
                <div class="blocky-tile-value" id="tile_queries">-</div>
                <div class="blocky-tile-label">{{ lang._('Queries (24h)') }}</div>
            </div>
            <div class="col-sm-2 blocky-tile">
                <div class="blocky-tile-value" id="tile_blocked">-</div>
                <div class="blocky-tile-label">{{ lang._('Blocked') }}</div>
            </div>
            <div class="col-sm-2 blocky-tile">
                <div class="blocky-tile-value" id="tile_blockrate">-</div>
                <div class="blocky-tile-label">{{ lang._('Block rate') }}</div>
            </div>
            <div class="col-sm-2 blocky-tile">
                <div class="blocky-tile-value" id="tile_cachehit">-</div>
                <div class="blocky-tile-label">{{ lang._('Cache hit rate') }}</div>
            </div>
            <div class="col-sm-2 blocky-tile">
                <div class="blocky-tile-value" id="tile_response">-</div>
                <div class="blocky-tile-label">{{ lang._('Avg response') }}</div>
            </div>
            <div class="col-sm-2 blocky-tile">
                <div class="blocky-tile-value" id="tile_cache_entries">-</div>
                <div class="blocky-tile-label">{{ lang._('Cache entries') }}</div>
            </div>
        </div>
    </div>

    <div class="content-box" style="margin-top: 1em;">
        <div class="content-box-main">
            <h3>{{ lang._('Queries per hour') }}</h3>
            <div class="blocky-chart-wrapper" id="blocky_hourly_wrapper">
                <canvas id="blocky_hourly"></canvas>
            </div>
        </div>
    </div>

    <div class="row" style="margin-top: 1em;">
        <div class="col-md-6">
            <div class="content-box">
                <div class="content-box-main">
                    <h3>{{ lang._('Response types') }}</h3>
                    <div class="blocky-chart-wrapper">
                        <canvas id="blocky_types"></canvas>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-md-6">
            <div class="content-box">
                <div class="content-box-main">
                    <h3>{{ lang._('Loaded lists') }}</h3>
                    <table class="table table-condensed blocky-top-table">
                        <thead>
                            <tr>
                                <th>{{ lang._('Kind') }}</th>
                                <th>{{ lang._('Group') }}</th>
                                <th class="blocky-count">{{ lang._('Entries') }}</th>
                            </tr>
                        </thead>
                        <tbody id="list_sizes"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <div class="row" style="margin-top: 1em;">
        <div class="col-md-4">
            <div class="content-box">
                <div class="content-box-main">
                    <h3>{{ lang._('Top domains') }}</h3>
                    <table class="table table-condensed blocky-top-table">
                        <thead>
                            <tr>
                                <th>{{ lang._('Domain') }}</th>
                                <th class="blocky-count">{{ lang._('Queries') }}</th>
                            </tr>
                        </thead>
                        <tbody id="top_domains"></tbody>
                    </table>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <div class="content-box">
                <div class="content-box-main">
                    <h3>{{ lang._('Top blocked domains') }}</h3>
                    <table class="table table-condensed blocky-top-table">
                        <thead>
                            <tr>
                                <th>{{ lang._('Domain') }}</th>
                                <th class="blocky-count">{{ lang._('Blocked') }}</th>
                            </tr>
                        </thead>
                        <tbody id="top_blocked"></tbody>
                    </table>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <div class="content-box">
                <div class="content-box-main">
                    <h3>{{ lang._('Top clients') }}</h3>
                    <table class="table table-condensed blocky-top-table">
                        <thead>
                            <tr>
                                <th>{{ lang._('Client') }}</th>
                                <th class="blocky-count">{{ lang._('Queries') }}</th>
                            </tr>
                        </thead>
                        <tbody id="top_clients"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="content-box" style="margin-top: 1em;">
    <div class="content-box-main">
        <h3>{{ lang._('Test a lookup') }}</h3>
        <p>{{ lang._('Ask the running blocky instance to resolve a name, to see whether it is blocked and where the answer comes from.') }}</p>
        <div class="form-inline">
            <input type="text" class="form-control" id="query_name" size="30"
                   placeholder="{{ lang._('example.com') }}"/>
            <select class="form-control" id="query_type">
                <option value="A">A</option>
                <option value="AAAA">AAAA</option>
                <option value="CNAME">CNAME</option>
                <option value="MX">MX</option>
                <option value="TXT">TXT</option>
                <option value="PTR">PTR</option>
                <option value="SRV">SRV</option>
                <option value="HTTPS">HTTPS</option>
            </select>
            <button class="btn btn-primary" id="act_query" type="button">
                <i class="fa fa-search fa-fw"></i> {{ lang._('Look up') }}
            </button>
        </div>
        <pre id="query_result" style="margin-top: 1em;"></pre>
    </div>
</div>
