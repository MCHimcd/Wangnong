/**
 * 鸿蒙慧田 — 智慧农业管理平台
 * main_debug.js — 全局数据驱动与页面控制器
 */

// ═══════════════════════════════════════════════════════════════════
//  全局状态与配置
// ═══════════════════════════════════════════════════════════════════
const POLL_INTERVAL = 5000;  // 数据刷新间隔 (ms)

let currentPage = 'dashboard';
let chartMain = null;  // 仪表盘主趋势图
let chartEnv  = null;  // 环境监测趋势图
let chartSoilMoist = null;
let npkCharts = {};
let confChart = null;
let sidebarCollapsed = false;

let latestTelemetry = null;
let latestDecision  = null;
let latestVisual    = null;
let historyTelemetry = [];
let historyDecisions = [];
let currentChartMode = 'temp_humidity';
let currentEnvChartMode = 'temp_humidity';

// ═══════════════════════════════════════════════════════════════════
//  页面切换
// ═══════════════════════════════════════════════════════════════════
const PAGE_TITLES = {
    dashboard: '仪表盘',
    environment: '环境监测',
    soil: '土壤监测',
    decision: 'AI决策中心',
    vision: '视觉病害',
    devices: '设备控制',
};

function switchPage(page) {
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    document.getElementById(`page-${page}`).classList.add('active');
    document.querySelector(`[data-page="${page}"]`).classList.add('active');
    document.getElementById('page-title').textContent = PAGE_TITLES[page] || page;
    currentPage = page;
    // 切换到对应页面时刷新图表以适应新尺寸
    setTimeout(() => {
        if (chartMain) chartMain.resize();
        if (chartEnv)  chartEnv.resize();
        if (chartSoilMoist) chartSoilMoist.resize();
    }, 50);
}

function toggleSidebar() {
    const sb = document.getElementById('sidebar');
    sb.classList.toggle('collapsed');
    sidebarCollapsed = !sidebarCollapsed;
}

// ═══════════════════════════════════════════════════════════════════
//  时钟
// ═══════════════════════════════════════════════════════════════════
function updateClock() {
    const now = new Date();
    const pad = n => String(n).padStart(2, '0');
    document.getElementById('topbar-time').textContent =
        `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}  ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
}

// ═══════════════════════════════════════════════════════════════════
//  Toast 通知
// ═══════════════════════════════════════════════════════════════════
function showToast(msg, type = '') {
    const t = document.getElementById('toast');
    t.textContent = msg;
    t.className = `toast show ${type}`;
    setTimeout(() => { t.className = 'toast'; }, 3000);
}

// ═══════════════════════════════════════════════════════════════════
//  趋势图初始化
// ═══════════════════════════════════════════════════════════════════
function buildChartDatasets(mode, rows) {
    const labels = rows.map(r => r.timestamp || r.created_at || '');
    let datasets = [];
    if (mode === 'temp_humidity') {
        datasets = [
            { label: '空气温度(°C)',  data: rows.map(r => r.air_temp),     borderColor: '#E65100', backgroundColor: 'rgba(230,81,0,0.08)', tension: 0.4, fill: true },
            { label: '空气湿度(%)',   data: rows.map(r => r.air_humidity),  borderColor: '#1565C0', backgroundColor: 'rgba(21,101,192,0.06)', tension: 0.4, fill: true },
        ];
    } else if (mode === 'soil') {
        datasets = [
            { label: '土壤温度(°C)', data: rows.map(r => r.soil_temp),     borderColor: '#E65100', tension: 0.4 },
            { label: '土壤湿度(%)',  data: rows.map(r => r.soil_moisture),  borderColor: '#2E7D32', tension: 0.4 },
        ];
    } else {
        datasets = [
            { label: 'CO₂(ppm)',     data: rows.map(r => r.co2_ppm),        borderColor: '#7B1FA2', tension: 0.4, yAxisID: 'y1' },
            { label: '光照(Lux/100)', data: rows.map(r => (r.light_intensity||0)/100), borderColor: '#F57F17', tension: 0.4, yAxisID: 'y' },
        ];
    }
    return { labels, datasets };
}

const chartDefaults = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
        legend: { position: 'top', labels: { font: { size: 11 }, boxWidth: 12, padding: 12 } },
        tooltip: { mode: 'index', intersect: false },
    },
    scales: {
        x: { ticks: { font: { size: 10 }, maxTicksLimit: 8 }, grid: { color: 'rgba(0,0,0,0.04)' } },
        y: { ticks: { font: { size: 10 } }, grid: { color: 'rgba(0,0,0,0.04)' } },
    },
    animation: { duration: 400 },
};

function initMainChart() {
    const ctx = document.getElementById('mainTrendChart').getContext('2d');
    chartMain = new Chart(ctx, { type: 'line', data: { labels: [], datasets: [] }, options: { ...chartDefaults } });
}

function initEnvChart() {
    const ctx = document.getElementById('envTrendChart').getContext('2d');
    chartEnv = new Chart(ctx, { type: 'line', data: { labels: [], datasets: [] }, options: { ...chartDefaults } });
}

function initSoilMoistChart() {
    const ctx = document.getElementById('soilMoistChart').getContext('2d');
    chartSoilMoist = new Chart(ctx, {
        type: 'line',
        data: { labels: [], datasets: [{ label: '土壤湿度(%)', data: [], borderColor: '#2E7D32', backgroundColor: 'rgba(46,125,50,0.08)', tension: 0.4, fill: true }] },
        options: { ...chartDefaults, plugins: { ...chartDefaults.plugins, legend: { display: false } } }
    });
}

function updateTrendChart(chart, mode, rows) {
    if (!chart || !rows.length) return;
    const { labels, datasets } = buildChartDatasets(mode, rows);
    chart.data.labels = labels;
    chart.data.datasets = datasets;
    chart.update('none');
}

function switchChart(mode) {
    currentChartMode = mode;
    document.querySelectorAll('#page-dashboard .chart-tab').forEach(t => t.classList.toggle('active', t.textContent.includes(mode === 'temp_humidity' ? '温湿度' : mode === 'soil' ? '土壤' : 'CO₂')));
    updateTrendChart(chartMain, mode, historyTelemetry);
}

function switchEnvChart(mode) {
    currentEnvChartMode = mode;
    document.querySelectorAll('#page-environment .chart-tab').forEach(t => t.classList.toggle('active', t.textContent.includes(mode === 'temp_humidity' ? '温湿度' : mode === 'soil' ? '土壤' : 'CO₂')));
    updateTrendChart(chartEnv, mode, historyTelemetry);
}

// ═══════════════════════════════════════════════════════════════════
//  NPK 迷你环形图
// ═══════════════════════════════════════════════════════════════════
function initNpkCharts() {
    const configs = [
        { id: 'npkN', color: '#2E7D32', bg: '#E8F5E9', valId: 'npk-n-val' },
        { id: 'npkP', color: '#1565C0', bg: '#E3F2FD', valId: 'npk-p-val' },
        { id: 'npkK', color: '#E65100', bg: '#FBE9E7', valId: 'npk-k-val' },
    ];
    configs.forEach(cfg => {
        const ctx = document.getElementById(cfg.id).getContext('2d');
        npkCharts[cfg.id] = new Chart(ctx, {
            type: 'doughnut',
            data: { datasets: [{ data: [0, 100], backgroundColor: [cfg.color, cfg.bg], borderWidth: 0, cutout: '75%' }] },
            options: { responsive: false, plugins: { legend: { display: false }, tooltip: { enabled: false } }, animation: { duration: 600 } }
        });
    });
}

function updateNpkCharts(n, p, k) {
    const nPct = Math.min(100, Math.max(0, ((n||0) / 150) * 100));
    const pPct = Math.min(100, Math.max(0, ((p||0) / 80)  * 100));
    const kPct = Math.min(100, Math.max(0, ((k||0) / 100) * 100));
    [[npkCharts['npkN'], nPct, 'npk-n-val', n],
     [npkCharts['npkP'], pPct, 'npk-p-val', p],
     [npkCharts['npkK'], kPct, 'npk-k-val', k]].forEach(([chart, pct, valId, raw]) => {
        if (!chart) return;
        chart.data.datasets[0].data = [pct, 100 - pct];
        chart.update('none');
        document.getElementById(valId).textContent = raw != null ? raw.toFixed(1) : '--';
    });
}

// ═══════════════════════════════════════════════════════════════════
//  Confidence Ring图
// ═══════════════════════════════════════════════════════════════════
function initConfChart() {
    const ctx = document.getElementById('confRing').getContext('2d');
    confChart = new Chart(ctx, {
        type: 'doughnut',
        data: { datasets: [{ data: [0, 100], backgroundColor: ['#2E7D32', '#E8F5E9'], borderWidth: 0, cutout: '72%' }] },
        options: { responsive: false, plugins: { legend: { display: false }, tooltip: { enabled: false } }, animation: { duration: 600 } }
    });
}

function updateConfChart(confidence) {
    const pct = confidence != null ? Math.round(confidence * 100) : 0;
    if (confChart) {
        confChart.data.datasets[0].data = [pct, 100 - pct];
        confChart.update('none');
    }
    document.getElementById('conf-center-val').textContent = confidence != null ? `${pct}%` : '--';
}

// ═══════════════════════════════════════════════════════════════════
//  设备状态渲染
// ═══════════════════════════════════════════════════════════════════
const DEVICE_CONFIG = [
    { key: 'water_pump_status',     name: '水泵',      icon: '💧' },
    { key: 'led_light_status',      name: '补光灯',    icon: '💡' },
    { key: 'fan_status',            name: '排风扇',    icon: '🌀' },
    { key: 'heater_status',         name: '加热器',    icon: '🔥' },
    { key: 'misting_status',        name: '喷雾器',    icon: '🌫️' },
    { key: 'co2_generator_status',  name: 'CO₂发生器', icon: '🌬️' },
    { key: 'fertilizer_status',     name: '水肥一体机',icon: '🌿' },
];

function renderDeviceMiniGrid(tel) {
    const container = document.getElementById('device-mini-grid');
    if (!container || !tel) return;
    container.innerHTML = DEVICE_CONFIG.map(d => {
        const on = tel[d.key] === 1 || tel[d.key] === true;
        return `<div class="device-mini-item">
            <span class="dev-icon">${d.icon}</span>
            <span class="dev-name">${d.name}</span>
            <span class="device-status-dot ${on ? 'on' : 'off'}"></span>
        </div>`;
    }).join('');
}

function renderDeviceFullGrid(tel) {
    const container = document.getElementById('device-status-grid');
    if (!container || !tel) return;
    container.innerHTML = DEVICE_CONFIG.map(d => {
        const on = tel[d.key] === 1 || tel[d.key] === true;
        return `<div class="device-card ${on ? 'on' : 'off'}">
            <span class="dc-icon">${d.icon}</span>
            <div class="dc-name">${d.name}</div>
            <div class="dc-status ${on ? 'on' : 'off'}">${on ? '● 运行中' : '○ 已停止'}</div>
        </div>`;
    }).join('');
}

// ═══════════════════════════════════════════════════════════════════
//  决策历史渲染
// ═══════════════════════════════════════════════════════════════════
const STATUS_LABEL = {
    completed: '已完成',
    waiting_for_human_input: '等待审核',
    strategy_ready: '策略就绪',
    error: '错误',
    pending: '处理中',
    recovering: '恢复中',
};

function renderDecisionHistory(list) {
    const container = document.getElementById('decision-history-scroll');
    if (!container) return;
    if (!list || !list.length) {
        container.innerHTML = '<div class="na-placeholder">暂无历史记录</div>';
        return;
    }
    container.innerHTML = list.map(item => {
        const statusClass = item.status === 'completed' ? 'completed' : item.status === 'waiting_for_human_input' ? 'waiting' : 'error';
        const anomalies = Array.isArray(item.anomalies_detected) ? item.anomalies_detected : [];
        const actions = Array.isArray(item.action_items) ? item.action_items : [];
        return `<div class="history-item ${statusClass}">
            <div class="hi-header">
                <span class="hi-id">ID: ${item.id}</span>
                <span class="hi-status ${statusClass}">${STATUS_LABEL[item.status] || item.status}</span>
            </div>
            <div class="hi-time">⏰ ${item.triggered_at || '--'}</div>
            ${anomalies.length ? `<div class="hi-anomalies">⚠️ ${anomalies.slice(0,3).map(a => `<span>${a}</span>`).join('')}${anomalies.length > 3 ? `<span>+${anomalies.length-3}条</span>` : ''}</div>` : ''}
            ${item.human_feedback ? `<div class="hi-anomalies" style="margin-top:4px;">💬 人工反馈: <span>${item.human_feedback}</span></div>` : ''}
        </div>`;
    }).join('');
}

// ═══════════════════════════════════════════════════════════════════
//  最新决策摘要渲染
// ═══════════════════════════════════════════════════════════════════
function renderLatestDecision(decision) {
    const container = document.getElementById('latest-decision-summary');
    if (!container) return;

    const commands = Array.isArray(decision.mqtt_commands) ? decision.mqtt_commands : [];
    const actions  = Array.isArray(decision.action_items) ? decision.action_items : [];
    const anomalies = Array.isArray(decision.anomalies_detected) ? decision.anomalies_detected : [];
    const statusClass = decision.status === 'completed' ? 'completed' : decision.status === 'waiting_for_human_input' ? 'waiting' : 'error';

    container.innerHTML = `
        <div class="decision-row"><span class="dr-label">决策 ID</span><span class="dr-value accent">#${decision.id || '--'}</span></div>
        <div class="decision-row"><span class="dr-label">状态</span><span class="status-badge ${statusClass}">${STATUS_LABEL[decision.status] || decision.status}</span></div>
        <div class="decision-row"><span class="dr-label">触发时间</span><span class="dr-value small">${decision.triggered_at || '--'}</span></div>
        <div class="decision-row"><span class="dr-label">异常数量</span><span class="dr-value danger">${anomalies.length} 条</span></div>
        <div class="decision-row"><span class="dr-label">下发指令</span><span class="dr-value accent">${commands.length} 条</span></div>
        ${decision.strategy ? `<div style="margin-top:12px;font-size:13px;color:#757575;line-height:1.6;max-height:100px;overflow:auto;">${decision.strategy}</div>` : ''}
    `;
}

// ═══════════════════════════════════════════════════════════════════
//  干预面板
// ═══════════════════════════════════════════════════════════════════
function renderInterventionPanel(decision) {
    const panel = document.getElementById('intervention-panel');
    const alertBadge = document.getElementById('alert-badge');
    if (!decision || decision.status !== 'waiting_for_human_input') {
        if (panel) panel.style.display = 'none';
        if (alertBadge) alertBadge.classList.add('hidden');
        return;
    }

    if (panel) panel.style.display = 'block';
    if (alertBadge) { alertBadge.classList.remove('hidden'); alertBadge.textContent = '1'; }

    const actions  = Array.isArray(decision.action_items) ? decision.action_items : [];
    const commands = Array.isArray(decision.mqtt_commands) ? decision.mqtt_commands : [];

    document.getElementById('intervention-decision-id').textContent = decision.id;
    document.getElementById('intervention-strategy').textContent = decision.strategy || '--';
    document.getElementById('intervention-actions').innerHTML = actions.map(a => `<li>${a}</li>`).join('') || '<li>无操作项</li>';

    const cmdsHtml = commands.map(cmd => {
        const action = cmd.payload?.action || {};
        const command = action.command || '';
        const device = action.target_device || '';
        const params = action.parameters ? JSON.stringify(action.parameters) : '';
        return `<div class="cmd-item ${command}"><span class="cmd-action ${command}">${command}</span> ${device} ${params}</div>`;
    }).join('');
    document.getElementById('intervention-commands').innerHTML = cmdsHtml || '<div style="color:#999;font-size:12px;">无指令</div>';
}

function submitIntervention() {
    if (!latestDecision || latestDecision.status !== 'waiting_for_human_input') {
        showToast('当前无需人工干预', '');
        return;
    }
    const feedback = document.getElementById('intervention-input').value.trim() || '人工确认，执行原方案';
    fetch('/api/submit-intervention', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ decision_id: latestDecision.id, feedback }),
    })
    .then(r => r.json())
    .then(data => {
        if (data.code === 200) {
            showToast('✅ 干预指令已发送，等待下一轮 Agent 响应', 'success');
            document.getElementById('intervention-input').value = '';
        } else {
            showToast(`❌ 发送失败: ${data.msg}`, 'error');
        }
    })
    .catch(() => showToast('❌ 网络异常', 'error'));
}

// ═══════════════════════════════════════════════════════════════════
//  命令列表渲染 (设备页)
// ═══════════════════════════════════════════════════════════════════
function renderCommandList(decisions) {
    const container = document.getElementById('command-list');
    if (!container) return;
    const allCommands = [];
    decisions.forEach(dec => {
        const commands = Array.isArray(dec.mqtt_commands) ? dec.mqtt_commands : [];
        commands.forEach(cmd => {
            allCommands.push({ ...cmd, triggered_at: dec.triggered_at });
        });
    });
    if (!allCommands.length) {
        container.innerHTML = '<div class="na-placeholder">暂无指令记录</div>';
        return;
    }
    container.innerHTML = allCommands.slice(0, 20).map(cmd => {
        const action = cmd.payload?.action || {};
        const command = action.command || '';
        const device = action.target_device || '';
        const params = action.parameters ? Object.entries(action.parameters).map(([k,v]) => `${k}: ${v}`).join(', ') : '无参数';
        return `<div class="command-item ${command}">
            <span class="cmd-device">${device}</span>
            <span class="cmd-action ${command}">${command || '—'}</span>
            <span class="cmd-params">${params}</span>
            <span class="cmd-time">${cmd.triggered_at || '--'}</span>
        </div>`;
    }).join('');
}

// ═══════════════════════════════════════════════════════════════════
//  异常预警渲染
// ═══════════════════════════════════════════════════════════════════
function renderAnomalies(anomalies) {
    const scroll = document.getElementById('anomaly-scroll');
    const countEl = document.getElementById('anomaly-count');
    if (!scroll) return;
    if (!anomalies || !anomalies.length) {
        scroll.innerHTML = '<div class="alert-empty">暂无异常，系统运行正常 ✅</div>';
        if (countEl) countEl.textContent = '0';
        return;
    }
    if (countEl) countEl.textContent = anomalies.length;
    scroll.innerHTML = anomalies.map(a => `
        <div class="alert-item">
            <span class="alert-item-dot ${a.toLowerCase().includes('严重') || a.toLowerCase().includes('danger') ? 'danger' : 'warning'}"></span>
            <span>${a}</span>
        </div>`).join('');
}

function renderVisionAnomalies(anomalies) {
    const container = document.getElementById('vision-anomaly-list');
    if (!container) return;
    if (!anomalies || !anomalies.length) {
        container.innerHTML = '<div class="na-placeholder">暂无检测异常</div>';
        return;
    }
    container.innerHTML = anomalies.map((a, i) =>
        `<div class="anomaly-list-item"><span class="anomaly-num">${i+1}</span><span>${a}</span></div>`
    ).join('');
}

// ═══════════════════════════════════════════════════════════════════
//  养分分析
// ═══════════════════════════════════════════════════════════════════
function renderNutrientAnalysis(tel) {
    const container = document.getElementById('nutrient-analysis');
    if (!container || !tel) return;
    const items = [];
    const n = tel.soil_n, p = tel.soil_p, k = tel.soil_k;
    if (n != null) {
        const cls = n < 20 ? 'danger' : n < 30 ? 'warn' : 'ok';
        const msg = n < 20 ? `⚠️ 氮(N)严重不足 (${n.toFixed(1)} mg/kg)，建议追施氮肥` : n < 30 ? `氮(N)偏低 (${n.toFixed(1)} mg/kg)，关注施肥` : `氮(N)正常 (${n.toFixed(1)} mg/kg)`;
        items.push({ cls, msg });
    }
    if (p != null) {
        const cls = p < 20 ? 'danger' : p < 25 ? 'warn' : 'ok';
        const msg = p < 20 ? `⚠️ 磷(P)严重不足 (${p.toFixed(1)} mg/kg)，建议追施磷肥` : p < 25 ? `磷(P)偏低 (${p.toFixed(1)} mg/kg)` : `磷(P)正常 (${p.toFixed(1)} mg/kg)`;
        items.push({ cls, msg });
    }
    if (k != null) {
        const cls = k < 20 ? 'danger' : k < 25 ? 'warn' : 'ok';
        const msg = k < 20 ? `⚠️ 钾(K)严重不足 (${k.toFixed(1)} mg/kg)，建议追施钾肥` : k < 25 ? `钾(K)偏低 (${k.toFixed(1)} mg/kg)` : `钾(K)正常 (${k.toFixed(1)} mg/kg)`;
        items.push({ cls, msg });
    }
    if (!items.length) { container.innerHTML = '<div class="na-placeholder">加载数据中...</div>'; return; }
    container.innerHTML = items.map(i => `<div class="na-item ${i.cls}">${i.msg}</div>`).join('');
}

// ═══════════════════════════════════════════════════════════════════
//  更新全部 UI
// ═══════════════════════════════════════════════════════════════════
function updateSidebarStatus(online) {
    const dot  = document.getElementById('sidebar-pulse');
    const text = document.getElementById('sidebar-status-text');
    if (online) {
        dot.classList.remove('error');
        text.textContent = '数据已同步';
    } else {
        dot.classList.add('error');
        text.textContent = '连接断开';
    }
}

function refreshDashboard() {
    const tel = latestTelemetry;
    const dec = latestDecision;
    const vis = latestVisual;

    // KPI 条
    if (tel) {
        setText('kpi-air-temp', tel.air_temp != null ? `${tel.air_temp.toFixed(1)} °C` : '-- °C');
        setText('kpi-air-hum',  tel.air_humidity != null ? `${tel.air_humidity.toFixed(1)} %` : '-- %');
        setText('kpi-light',    tel.light_intensity != null ? `${Math.round(tel.light_intensity)} Lux` : '-- Lux');
        setText('kpi-co2',      tel.co2_ppm != null ? `${Math.round(tel.co2_ppm)} ppm` : '-- ppm');
        setText('kpi-soil-moist', tel.soil_moisture != null ? `${tel.soil_moisture.toFixed(1)} %` : '-- %');
        setText('kpi-ph',       tel.soil_ph != null ? tel.soil_ph.toFixed(1) : '--');

        // 设备
        renderDeviceMiniGrid(tel);
        updateNpkCharts(tel.soil_n, tel.soil_p, tel.soil_k);
    }

    // 决策摘要
    if (dec) {
        const anomalies = Array.isArray(dec.anomalies_detected) ? dec.anomalies_detected : [];
        const commands  = Array.isArray(dec.mqtt_commands) ? dec.mqtt_commands : [];
        const statusClass = dec.status === 'completed' ? 'completed' : dec.status === 'waiting_for_human_input' ? 'waiting' : 'error';
        const badge = document.getElementById('agent-status-badge');
        if (badge) { badge.textContent = STATUS_LABEL[dec.status] || dec.status; badge.className = `status-badge ${statusClass}`; }
        setText('dash-decision-id', `#${dec.id || '--'}`);
        setText('dash-triggered-at', dec.triggered_at || '--');
        setText('dash-completed-at', dec.completed_at || '--');
        setText('dash-cmd-count', `${commands.length} 条`);
        renderAnomalies(anomalies);
    }

    // 视觉
    if (vis) {
        setText('dash-crop-type', vis.crop_type || '--');
        setText('dash-health', vis.health_status || '--');
        setText('dash-disease', vis.disease_name || '--');
        setText('dash-confidence', vis.confidence != null ? `${(vis.confidence * 100).toFixed(1)}%` : '--');
        setText('dash-crop-count', vis.crop_count != null ? `${vis.crop_count} 株` : '--');
        setText('dash-yield', vis.yield_estimation != null ? `${vis.yield_estimation} kg` : '-- kg');
        const healthDot = document.getElementById('health-dot');
        if (healthDot) {
            healthDot.className = `health-dot ${(vis.health_status || '').toLowerCase().includes('disease') ? 'diseased' : 'healthy'}`;
        }
    }
}

function refreshEnvironment() {
    const tel = latestTelemetry;
    if (!tel) return;
    setText('env-air-temp',   tel.air_temp != null ? `${tel.air_temp.toFixed(1)}°C` : '--°C');
    setText('env-air-hum',    tel.air_humidity != null ? `${tel.air_humidity.toFixed(1)}%` : '--%');
    setText('env-light',      tel.light_intensity != null ? `${Math.round(tel.light_intensity)} Lux` : '-- Lux');
    setText('env-co2',        tel.co2_ppm != null ? `${Math.round(tel.co2_ppm)} ppm` : '-- ppm');
    setText('env-soil-temp',  tel.soil_temp != null ? `${tel.soil_temp.toFixed(1)}°C` : '--°C');
    setText('env-soil-moist', tel.soil_moisture != null ? `${tel.soil_moisture.toFixed(1)}%` : '--%');
    setText('env-soil-ph',    tel.soil_ph != null ? tel.soil_ph.toFixed(1) : '--');
    setText('env-timestamp',  tel.timestamp || tel.created_at || '--');
    setText('env-device-id',  tel.device_id || '--');
    setText('env-system-mode', tel.system_mode || '--');
}

function refreshSoil() {
    const tel = latestTelemetry;
    if (!tel) return;
    setText('soil-temp',  tel.soil_temp != null ? `${tel.soil_temp.toFixed(1)} °C` : '-- °C');
    setText('soil-moist', tel.soil_moisture != null ? `${tel.soil_moisture.toFixed(1)} %` : '-- %');
    setText('soil-ph-val', tel.soil_ph != null ? tel.soil_ph.toFixed(1) : '--');
    // NPK bars
    const n = tel.soil_n, p = tel.soil_p, k = tel.soil_k;
    setNpkBar('soil-n-value', 'soil-n-bar', n, 150, 'N');
    setNpkBar('soil-p-value', 'soil-p-bar', p, 80,  'P');
    setNpkBar('soil-k-value', 'soil-k-bar', k, 100, 'K');
    renderNutrientAnalysis(tel);
    // Soil moisture chart
    if (chartSoilMoist && historyTelemetry.length) {
        chartSoilMoist.data.labels = historyTelemetry.map(r => r.timestamp || '');
        chartSoilMoist.data.datasets[0].data = historyTelemetry.map(r => r.soil_moisture);
        chartSoilMoist.update('none');
    }
}

function setNpkBar(valElId, barElId, value, max, unit) {
    setText(valElId, value != null ? `${value.toFixed(1)} mg/kg` : '-- mg/kg');
    const bar = document.getElementById(barElId);
    if (bar) bar.style.width = value != null ? `${Math.min(100, (value / max) * 100)}%` : '0%';
}

function refreshDecision() {
    if (latestDecision) {
        renderLatestDecision(latestDecision);
        renderInterventionPanel(latestDecision);
    }
    renderDecisionHistory(historyDecisions);
}

function refreshVision() {
    const vis = latestVisual;
    const dec = latestDecision;
    if (vis) {
        setText('vis-device',     vis.device_id || '--');
        setText('vis-crop',       vis.crop_type || '--');
        setText('vis-health',     vis.health_status || '--');
        setText('vis-disease',    vis.disease_name || '--');
        setText('vis-confidence', vis.confidence != null ? `${(vis.confidence * 100).toFixed(1)}%` : '--');
        setText('vis-count',      vis.crop_count != null ? `${vis.crop_count} 株` : '--');
        setText('vis-yield',      vis.yield_estimation != null ? `${vis.yield_estimation} kg` : '-- kg');
        setText('vis-time',       vis.timestamp || vis.created_at || '--');
        setText('vis-recommendation', vis.recommendation || '--');
        updateConfChart(vis.confidence);
    }
    if (dec) {
        const anomalies = Array.isArray(dec.anomalies_detected) ? dec.anomalies_detected : [];
        renderVisionAnomalies(anomalies);
    }
}

function refreshDevices() {
    renderDeviceFullGrid(latestTelemetry);
    renderCommandList(historyDecisions);
}

function setText(id, val) {
    const el = document.getElementById(id);
    if (el) el.textContent = val;
}

// ═══════════════════════════════════════════════════════════════════
//  数据拉取
// ═══════════════════════════════════════════════════════════════════
async function fetchAll() {
    try {
        const [telRes, decRes, visRes, histTelRes, histDecRes] = await Promise.all([
            fetch('/api/latest-telemetry'),
            fetch('/api/latest-decision'),
            fetch('/api/latest-visual'),
            fetch('/api/historical-telemetry'),
            fetch('/api/historical-decisions'),
        ]);
        latestTelemetry  = await telRes.json();
        latestDecision   = await decRes.json();
        latestVisual     = await visRes.json();
        historyTelemetry = await histTelRes.json() || [];
        historyDecisions = await histDecRes.json() || [];

        // 历史决策 — parse JSON fields
        historyDecisions.forEach(item => {
            ['anomalies_detected', 'action_items', 'mqtt_commands'].forEach(key => {
                if (typeof item[key] === 'string') {
                    try { item[key] = JSON.parse(item[key]); } catch { item[key] = []; }
                }
            });
        });

        updateSidebarStatus(true);

        // 刷新当前页面
        refreshDashboard();
        refreshEnvironment();
        refreshSoil();
        refreshDecision();
        refreshVision();
        refreshDevices();

        // 刷新图表
        updateTrendChart(chartMain, currentChartMode, historyTelemetry);
        updateTrendChart(chartEnv,  currentEnvChartMode, historyTelemetry);

    } catch (err) {
        console.error('[数据拉取异常]', err);
        updateSidebarStatus(false);
    }
}

// ═══════════════════════════════════════════════════════════════════
//  初始化
// ═══════════════════════════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', () => {
    initMainChart();
    initEnvChart();
    initSoilMoistChart();
    initNpkCharts();
    initConfChart();

    fetchAll();
    setInterval(fetchAll, POLL_INTERVAL);
    setInterval(updateClock, 1000);
    updateClock();
});
