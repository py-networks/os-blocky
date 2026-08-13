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

export default class Blocky extends BaseTableWidget {
    constructor() {
        super();
        this.tickTimeout = 30;
    }

    getGridOptions() {
        return {
            sizeToContent: 500
        };
    }

    getMarkup() {
        let $container = $('<div></div>');
        $container.append(this.createTable('blocky-status-table', {
            headerPosition: 'left'
        }));
        return $container;
    }

    async onWidgetTick() {
        const service = await this.ajaxCall('/api/blocky/service/status');
        if (!service || service.status !== 'running') {
            this._showMessage(this.translations.servicestopped);
            return;
        }

        const blocking = await this.ajaxCall('/api/blocky/blocking/status');
        const stats = await this.ajaxCall('/api/blocky/status/stats');

        const rows = this._buildRows(blocking, stats);
        if (!this.dataChanged('blocky-status', rows)) {
            return;
        }

        super.updateTable('blocky-status-table', rows);
    }

    _showMessage(message) {
        $('#blocky-status-table').empty().append(
            $('<div class="error-message"></div>').text(message)
        );
    }

    _label(cssClass, text) {
        return $('<div></div>').append(
            $('<span></span>').addClass('label label-' + cssClass).text(text)
        ).html();
    }

    _number(value) {
        return (value || 0).toLocaleString();
    }

    _buildRows(blocking, stats) {
        let rows = [];

        if (blocking && blocking.status === 'ok' && blocking.result) {
            const state = blocking.result;
            if (state.enabled) {
                rows.push([this.translations.blocking, this._label('success', this.translations.on)]);
            } else {
                let text = this.translations.off;
                if (state.autoEnableInSec) {
                    text += ' (' + Math.ceil(state.autoEnableInSec / 60) + ' '
                         + this.translations.minutesleft + ')';
                }
                rows.push([this.translations.blocking, this._label('warning', text)]);

                if (state.disabledGroups && state.disabledGroups.length) {
                    rows.push([this.translations.disabledgroups,
                               $('<div></div>').text(state.disabledGroups.join(', ')).html()]);
                }
            }
        } else {
            rows.push([this.translations.blocking, this._label('default', this.translations.unknown)]);
        }

        if (stats && stats.status === 'ok' && stats.result) {
            const summary = stats.result.summary || {};
            const blockRate = summary.queries
                ? ((summary.blocked / summary.queries) * 100).toFixed(1) + '%'
                : '0.0%';

            rows.push([this.translations.queries, this._number(summary.queries)]);
            rows.push([this.translations.blocked, this._number(summary.blocked) + ' (' + blockRate + ')']);
            rows.push([this.translations.cachehitrate,
                       ((summary.cacheHitRate || 0) * 100).toFixed(1) + '%']);

            const lists = (stats.result.lists || {}).denylist || {};
            let total = 0;
            Object.keys(lists).forEach((group) => {
                total += lists[group];
            });
            if (Object.keys(lists).length) {
                rows.push([this.translations.listentries, this._number(total)]);
            }
        } else if (stats && stats.message) {
            rows.push([this.translations.statistics,
                       $('<div></div>').text(stats.message).html()]);
        }

        return rows;
    }
}
