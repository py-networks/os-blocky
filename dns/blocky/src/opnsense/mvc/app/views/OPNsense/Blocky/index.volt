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
    $(document).ready(function() {
        const settingsForms = [
            'frm_General', 'frm_Upstreams', 'frm_Blocking', 'frm_CustomDNS',
            'frm_Conditional', 'frm_Caching', 'frm_Querylog', 'frm_Encryption', 'frm_Advanced'
        ];

        let loadMap = {};
        settingsForms.forEach(function(frm) {
            loadMap[frm] = "/api/blocky/settings/get";
        });

        mapDataToFormUI(loadMap).done(function() {
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
            updateServiceControlUI('blocky');
        });

        /**
         * Every tab is a separate form over the same model, so an apply has to push them one
         * after another. The chain stops at the first form the backend rejects, which leaves the
         * validation messages of that form on screen.
         */
        function saveAllSettings() {
            let chain = $.Deferred().resolve();
            settingsForms.forEach(function(frm) {
                chain = chain.then(function() {
                    const step = $.Deferred();
                    saveFormToEndpoint("/api/blocky/settings/set", frm, step.resolve, true, step.reject);
                    return step;
                });
            });
            return chain;
        }

        $("#reconfigureAct").SimpleActionButton({
            onPreAction: function() {
                const dfObj = $.Deferred();
                saveAllSettings().done(dfObj.resolve).fail(dfObj.reject);
                return dfObj;
            },
            onAction: function() {
                updateServiceControlUI('blocky');
            }
        });

        /* every grid id matches the suffix of its API endpoints */
        [
            'upstream', 'denylist', 'allowlist', 'clientgroup', 'schedule',
            'listschedule', 'mapping', 'rewrite', 'forward'
        ].forEach(function(grid) {
            $("#" + grid).UIBootgrid({
                search: '/api/blocky/settings/search_' + grid + '/',
                get: '/api/blocky/settings/get_' + grid + '/',
                set: '/api/blocky/settings/set_' + grid + '/',
                add: '/api/blocky/settings/add_' + grid + '/',
                del: '/api/blocky/settings/del_' + grid + '/',
                toggle: '/api/blocky/settings/toggle_' + grid + '/'
            });
        });
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
    <li><a data-toggle="tab" href="#upstreams">{{ lang._('Upstreams') }}</a></li>
    <li><a data-toggle="tab" href="#blocking">{{ lang._('Blocking') }}</a></li>
    <li><a data-toggle="tab" href="#clientgroups">{{ lang._('Client Groups') }}</a></li>
    <li><a data-toggle="tab" href="#schedules">{{ lang._('Schedules') }}</a></li>
    <li><a data-toggle="tab" href="#customdns">{{ lang._('Custom DNS') }}</a></li>
    <li><a data-toggle="tab" href="#conditional">{{ lang._('Conditional') }}</a></li>
    <li><a data-toggle="tab" href="#caching">{{ lang._('Caching') }}</a></li>
    <li><a data-toggle="tab" href="#querylog">{{ lang._('Query Log') }}</a></li>
    <li><a data-toggle="tab" href="#encryption">{{ lang._('Encryption') }}</a></li>
    <li><a data-toggle="tab" href="#advanced">{{ lang._('Advanced') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="general" class="tab-pane fade in active">
        {{ partial('layout_partials/base_form', ['fields': generalForm, 'id': 'frm_General']) }}
    </div>

    <div id="upstreams" class="tab-pane fade in">
        {{ partial('layout_partials/base_form', ['fields': upstreamsForm, 'id': 'frm_Upstreams']) }}
        {{ partial('layout_partials/base_bootgrid_table', formGridUpstream) }}
    </div>

    <div id="blocking" class="tab-pane fade in">
        {{ partial('layout_partials/base_form', ['fields': blockingForm, 'id': 'frm_Blocking']) }}
        <div class="content-box-main">
            <h3>{{ lang._('Block Lists') }}</h3>
        </div>
        {{ partial('layout_partials/base_bootgrid_table', formGridDenylist) }}
        <div class="content-box-main">
            <h3>{{ lang._('Allow Lists') }}</h3>
        </div>
        {{ partial('layout_partials/base_bootgrid_table', formGridAllowlist) }}
    </div>

    <div id="clientgroups" class="tab-pane fade in">
        <div class="content-box-main">
            <p>
                {{ lang._('Blocking only takes effect for clients listed here. Use the client "default" to
                          apply lists to every client that is not matched by a more specific entry.') }}
            </p>
        </div>
        {{ partial('layout_partials/base_bootgrid_table', formGridClientgroup) }}
    </div>

    <div id="schedules" class="tab-pane fade in">
        <div class="content-box-main">
            <h3>{{ lang._('Schedules') }}</h3>
        </div>
        {{ partial('layout_partials/base_bootgrid_table', formGridSchedule) }}
        <div class="content-box-main">
            <h3>{{ lang._('Scheduled List Groups') }}</h3>
        </div>
        {{ partial('layout_partials/base_bootgrid_table', formGridListschedule) }}
    </div>

    <div id="customdns" class="tab-pane fade in">
        {{ partial('layout_partials/base_form', ['fields': customdnsForm, 'id': 'frm_CustomDNS']) }}
        <div class="content-box-main">
            <h3>{{ lang._('Mappings') }}</h3>
        </div>
        {{ partial('layout_partials/base_bootgrid_table', formGridMapping) }}
        <div class="content-box-main">
            <h3>{{ lang._('Domain Rewrites') }}</h3>
        </div>
        {{ partial('layout_partials/base_bootgrid_table', formGridRewrite) }}
    </div>

    <div id="conditional" class="tab-pane fade in">
        {{ partial('layout_partials/base_form', ['fields': conditionalForm, 'id': 'frm_Conditional']) }}
        {{ partial('layout_partials/base_bootgrid_table', formGridForward) }}
    </div>

    <div id="caching" class="tab-pane fade in">
        {{ partial('layout_partials/base_form', ['fields': cachingForm, 'id': 'frm_Caching']) }}
    </div>

    <div id="querylog" class="tab-pane fade in">
        {{ partial('layout_partials/base_form', ['fields': querylogForm, 'id': 'frm_Querylog']) }}
    </div>

    <div id="encryption" class="tab-pane fade in">
        {{ partial('layout_partials/base_form', ['fields': encryptionForm, 'id': 'frm_Encryption']) }}
    </div>

    <div id="advanced" class="tab-pane fade in">
        {{ partial('layout_partials/base_form', ['fields': advancedForm, 'id': 'frm_Advanced']) }}
    </div>
</div>

{{ partial('layout_partials/base_apply_button', {
    'data_endpoint': '/api/blocky/service/reconfigure',
    'data_service_widget': 'blocky'
}) }}

{{ partial('layout_partials/base_dialog', ['fields': formDialogUpstream, 'id': formGridUpstream['edit_dialog_id'], 'label': lang._('Edit Upstream')]) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogDenylist, 'id': formGridDenylist['edit_dialog_id'], 'label': lang._('Edit Block List')]) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogAllowlist, 'id': formGridAllowlist['edit_dialog_id'], 'label': lang._('Edit Allow List')]) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogClientgroup, 'id': formGridClientgroup['edit_dialog_id'], 'label': lang._('Edit Client Group')]) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogSchedule, 'id': formGridSchedule['edit_dialog_id'], 'label': lang._('Edit Schedule')]) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogListschedule, 'id': formGridListschedule['edit_dialog_id'], 'label': lang._('Edit Scheduled List Group')]) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogMapping, 'id': formGridMapping['edit_dialog_id'], 'label': lang._('Edit Mapping')]) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogRewrite, 'id': formGridRewrite['edit_dialog_id'], 'label': lang._('Edit Domain Rewrite')]) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogForward, 'id': formGridForward['edit_dialog_id'], 'label': lang._('Edit Forwarding Rule')]) }}
