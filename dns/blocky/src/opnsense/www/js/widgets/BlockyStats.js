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

export default class BlockyStats extends BaseWidget {
    constructor() {
        super();
        this.chart = null;
        this.tickTimeout = 60;
        this.hourFormat = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' });
    }

    getGridOptions() {
        return {
            sizeToContent: 460
        };
    }

    getMarkup() {
        return $(`
            <div class="blocky-stats-widget">
                <div class="blocky-stats-summary" style="display: flex; justify-content: space-around; margin-bottom: 8px;">
                    <div style="text-align: center;">
                        <div id="${this.id}-queries" style="font-size: 18px; font-weight: 600;">-</div>
                        <div style="font-size: 11px; opacity: 0.7;">${this.translations.queries}</div>
                    </div>
                    <div style="text-align: center;">
                        <div id="${this.id}-blocked" style="font-size: 18px; font-weight: 600;">-</div>
                        <div style="font-size: 11px; opacity: 0.7;">${this.translations.blocked}</div>
                    </div>
                    <div style="text-align: center;">
                        <div id="${this.id}-rate" style="font-size: 18px; font-weight: 600;">-</div>
                        <div style="font-size: 11px; opacity: 0.7;">${this.translations.blockrate}</div>
                    </div>
                </div>
                <div id="${this.id}-message" class="error-message" style="display: none;"></div>
                <div class="canvas-container" style="position: relative; height: 220px;">
                    <canvas id="${this.id}-chart"></canvas>
                </div>
            </div>
        `);
    }

    async onWidgetTick() {
        const stats = await this.ajaxCall('/api/blocky/status/stats');

        if (!stats || stats.status !== 'ok' || !stats.result) {
            const message = (stats && stats.message) ? stats.message : this.translations.nodata;
            $(`#${this.id}-message`).show().text(message);
            $(`.blocky-stats-widget .canvas-container`).hide();
            return;
        }

        $(`#${this.id}-message`).hide();
        $(`.blocky-stats-widget .canvas-container`).show();

        const summary = stats.result.summary || {};
        const rate = summary.queries ? (summary.blocked / summary.queries) * 100 : 0;

        $(`#${this.id}-queries`).text((summary.queries || 0).toLocaleString());
        $(`#${this.id}-blocked`).text((summary.blocked || 0).toLocaleString());
        $(`#${this.id}-rate`).text(rate.toFixed(1) + '%');

        this._renderChart(stats.result.perHour || []);
    }

    /* blocky reports every bucket as an RFC 3339 instant in UTC ("2026-08-15T13:00:00Z").
       Slicing the string would label the bars in UTC while the rest of the dashboard is in the
       browser's zone, so parse it and let Intl render it locally, the way core's Firewall widget
       labels its own time axis. */
    _hourLabel(value) {
        const when = new Date(value);
        if (isNaN(when.getTime())) {
            return String(value || '');
        }
        return this.hourFormat.format(when);
    }

    _renderChart(perHour) {
        const labels = perHour.map((row) => this._hourLabel(row.hour));
        /* "queries" is the total, so the allowed share is what is left after blocked and filtered */
        const allowed = perHour.map((row) =>
            Math.max((row.queries || 0) - (row.blocked || 0) - (row.filtered || 0), 0));
        const blocked = perHour.map((row) => row.blocked || 0);

        if (this.chart !== null) {
            this.chart.data.labels = labels;
            this.chart.data.datasets[0].data = allowed;
            this.chart.data.datasets[1].data = blocked;
            this.chart.update();
            return;
        }

        const context = document.getElementById(`${this.id}-chart`).getContext('2d');
        this.chart = new Chart(context, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: this.translations.allowed,
                        data: allowed,
                        backgroundColor: '#3c8dbc',
                        maxBarThickness: 40
                    },
                    {
                        label: this.translations.blocked,
                        data: blocked,
                        backgroundColor: '#d94f00',
                        maxBarThickness: 40
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { stacked: true, ticks: { maxTicksLimit: 12 } },
                    y: { stacked: true, beginAtZero: true }
                },
                plugins: {
                    legend: { position: 'bottom' },
                    /* the dashboard loads chartjs-plugin-colorschemes, which would otherwise
                       repaint both datasets from its palette and lose the allowed/blocked contrast */
                    colorschemes: false
                }
            }
        });
    }

    onWidgetClose() {
        if (this.chart !== null) {
            this.chart.destroy();
            this.chart = null;
        }
    }
}
