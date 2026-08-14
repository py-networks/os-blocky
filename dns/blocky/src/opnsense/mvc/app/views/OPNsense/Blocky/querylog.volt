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

<script>
    'use strict';

    $(document).ready(function() {
        let currentFile = '';

        function esc(value) {
            return $('<div/>').text(value === null || value === undefined ? '' : value).html();
        }

        function reasonFormatter(column, row) {
            const type = row.response_type || '';
            let style = 'default';
            if (type === 'BLOCKED') {
                style = 'danger';
            } else if (type === 'CACHED') {
                style = 'info';
            } else if (type === 'RESOLVED') {
                style = 'success';
            } else if (type === 'FILTERED' || type === 'NOTFQDN') {
                style = 'warning';
            }
            /*
             * The reason usually repeats the response type before its detail, as in
             * "BLOCKED (ads: doubleclick.net)". The badge already carries the type, so only the
             * detail is worth the column width.
             */
            let detail = row.reason || '';
            if (type && detail.startsWith(type)) {
                detail = detail.substring(type.length).trim();
            }

            return '<span class="label label-' + style + '">' + esc(type || '-') + '</span>'
                 + (detail ? ' ' + esc(detail) : '');
        }

        const grid = $("#grid-querylog").UIBootgrid({
            search: '/api/blocky/querylog/search/',
            options: {
                navigation: 3,
                rowCount: [50, 100, 250, 500],
                requestHandler: function(request) {
                    request['file'] = currentFile;
                    return request;
                },
                formatters: {
                    reason: reasonFormatter
                }
            }
        });

        function loadFiles() {
            ajaxGet('/api/blocky/querylog/files', {}, function(data) {
                const $select = $('#logfile');
                $select.empty();

                if (!data || data.status !== 'ok' || !data.files || data.files.length === 0) {
                    $('#querylog_notice').removeClass('hidden').text(
                        "{{ lang._('No query log files found. Enable the query log on the Query Log tab of the settings page.') }}"
                    );
                    $select.append($('<option></option>').val('').text("{{ lang._('None') }}"));
                    $select.selectpicker('refresh');
                    return;
                }

                $('#querylog_notice').addClass('hidden');
                data.files.forEach(function(name) {
                    $select.append($('<option></option>').val(name).text(name));
                });
                currentFile = data.files[0];
                $select.selectpicker('refresh');
                $('#grid-querylog').bootgrid('reload');
            });
        }

        $('#logfile').change(function() {
            currentFile = $(this).val();
            $('#grid-querylog').bootgrid('reload');
        });

        $('#act_reload').click(function() {
            loadFiles();
        });

        loadFiles();
    });
</script>

<div id="querylog_notice" class="alert alert-info hidden" role="alert"></div>

<div class="content-box">
    <div class="content-box-main">
        <div class="form-inline" style="margin-bottom: 1em;">
            <label for="logfile">{{ lang._('Log file') }}&nbsp;</label>
            <select id="logfile" class="selectpicker" data-width="auto"></select>
            <button class="btn btn-default" id="act_reload" type="button">
                <i class="fa fa-refresh fa-fw"></i> {{ lang._('Reload') }}
            </button>
        </div>

        <table id="grid-querylog" class="table table-condensed table-hover table-striped">
            <thead>
                <tr>
                    <th data-column-id="time" data-type="string" data-identifier="true" data-width="11em">{{ lang._('Time') }}</th>
                    <th data-column-id="client_ip" data-type="string" data-width="9em">{{ lang._('Client') }}</th>
                    <th data-column-id="client_name" data-type="string" data-width="9em" data-visible="false">{{ lang._('Name') }}</th>
                    <th data-column-id="question" data-type="string">{{ lang._('Question') }}</th>
                    <th data-column-id="question_type" data-type="string" data-width="5em">{{ lang._('Type') }}</th>
                    <th data-column-id="reason" data-type="string" data-formatter="reason">{{ lang._('Result') }}</th>
                    <th data-column-id="answer" data-type="string">{{ lang._('Answer') }}</th>
                    <th data-column-id="response_code" data-type="string" data-width="7em">{{ lang._('Code') }}</th>
                    <th data-column-id="duration_ms" data-type="string" data-width="4em">{{ lang._('ms') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>
</div>
