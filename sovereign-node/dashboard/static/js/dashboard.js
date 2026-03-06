/**
 * SovereignNode Dashboard — Client-side JavaScript
 * Handles auto-refresh, status updates, and interactive features.
 */

// Auto-refresh system metrics every 30 seconds
const REFRESH_INTERVAL_MS = 30_000;

async function fetchJSON(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (err) {
    console.warn(`Failed to fetch ${url}:`, err.message);
    return null;
  }
}

/**
 * Update metric cards with fresh data from /api/status
 */
async function refreshMetrics() {
  const data = await fetchJSON('/api/status');
  if (!data?.system) return;

  const s = data.system;

  updateMetricCard('cpu_percent', `${s.cpu_percent}%`, `${s.cpu_count} cores`);
  updateMetricCard('memory', `${s.memory_used_gb} GB`, `of ${s.memory_total_gb} GB`);
  updateMetricCard('disk', `${s.disk_percent}%`, `${s.disk_free_gb} GB free`);

  updateProgressBar('cpu_progress', s.cpu_percent);
  updateProgressBar('memory_progress', s.memory_percent);
  updateProgressBar('disk_progress', s.disk_percent);
}

function updateMetricCard(id, value, sub) {
  const valueEl = document.querySelector(`[data-metric="${id}"] .metric-value`);
  const subEl = document.querySelector(`[data-metric="${id}"] .metric-sub`);
  if (valueEl) valueEl.textContent = value;
  if (subEl) subEl.textContent = sub;
}

function updateProgressBar(id, percent) {
  const bar = document.getElementById(id);
  if (bar) bar.style.width = `${Math.min(percent, 100)}%`;
}

/**
 * Initialize tooltips on service cards
 */
function initTooltips() {
  document.querySelectorAll('[data-tooltip]').forEach(el => {
    el.title = el.dataset.tooltip;
  });
}

/**
 * Format bytes to human readable
 */
function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
  return `${(bytes / 1024 ** 3).toFixed(1)} GB`;
}

/**
 * Show a toast notification
 */
function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  toast.style.cssText = `
    position: fixed; bottom: 20px; right: 20px; z-index: 9999;
    background: #1e2a4a; color: #e0e6ff; padding: 12px 20px;
    border-radius: 8px; border-left: 3px solid #7c6af7;
    font-size: 13px; animation: slideIn 0.3s ease;
    box-shadow: 0 4px 20px rgba(0,0,0,0.5);
  `;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

// ── DOMContentLoaded ─────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  initTooltips();

  // Start periodic refresh if on dashboard page
  if (document.querySelector('.metrics-grid')) {
    setInterval(refreshMetrics, REFRESH_INTERVAL_MS);
  }

  // Handle "Open" service links with loading state
  document.querySelectorAll('.service-card a').forEach(link => {
    link.addEventListener('click', (e) => {
      const btn = link.querySelector('button');
      if (btn) {
        const original = btn.textContent;
        btn.textContent = '...';
        setTimeout(() => { btn.textContent = original; }, 1500);
      }
    });
  });

  // Node info footer
  fetchJSON('/api/node/info').then(info => {
    if (!info) return;
    const footer = document.createElement('div');
    footer.style.cssText = 'position:fixed;bottom:8px;left:230px;font-size:10px;color:#4a5568;';
    footer.textContent = `${info.hostname} · Tier ${info.tier.toUpperCase()} · SovereignNode v${info.version}`;
    document.body.appendChild(footer);
  });
});
