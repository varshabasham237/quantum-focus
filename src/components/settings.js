/**
 * Settings component
 */

import { showToast } from './toast.js';

export function renderSettings(container, sessionManager) {
    const settings = sessionManager.getSettings();

    container.innerHTML = `
    <div class="page-header">
      <h1>⚙️ Settings</h1>
      <p>Customize your QuantumFocus experience</p>
    </div>

    <!-- Timer Settings -->
    <div class="card" style="margin-bottom: var(--sp-6);">
      <div class="card-title">Timer Configuration</div>

      <div class="setting-group">
        <div class="setting-row">
          <div>
            <div class="setting-label">Focus Duration</div>
            <div class="setting-desc">Length of each focus interval</div>
          </div>
          <div style="display: flex; align-items: center; gap: var(--sp-3);">
            <input type="range" id="setting-focus" min="5" max="60" step="5" value="${settings.focusDuration}" />
            <span id="setting-focus-val" style="font-family: var(--font-mono); font-size: var(--fs-sm); color: var(--text-primary); width: 50px;">${settings.focusDuration} min</span>
          </div>
        </div>
      </div>

      <div class="setting-group">
        <div class="setting-row">
          <div>
            <div class="setting-label">Short Break</div>
            <div class="setting-desc">Break between focus intervals</div>
          </div>
          <div style="display: flex; align-items: center; gap: var(--sp-3);">
            <input type="range" id="setting-short-break" min="1" max="15" step="1" value="${settings.shortBreak}" />
            <span id="setting-short-break-val" style="font-family: var(--font-mono); font-size: var(--fs-sm); color: var(--text-primary); width: 50px;">${settings.shortBreak} min</span>
          </div>
        </div>
      </div>

      <div class="setting-group">
        <div class="setting-row">
          <div>
            <div class="setting-label">Long Break</div>
            <div class="setting-desc">Break after ${settings.sessionsBeforeLong} focus intervals</div>
          </div>
          <div style="display: flex; align-items: center; gap: var(--sp-3);">
            <input type="range" id="setting-long-break" min="5" max="30" step="5" value="${settings.longBreak}" />
            <span id="setting-long-break-val" style="font-family: var(--font-mono); font-size: var(--fs-sm); color: var(--text-primary); width: 50px;">${settings.longBreak} min</span>
          </div>
        </div>
      </div>

      <div class="setting-group">
        <div class="setting-row">
          <div>
            <div class="setting-label">Check-in Interval</div>
            <div class="setting-desc">How often the quantum observer measures your state (±30% randomness)</div>
          </div>
          <div style="display: flex; align-items: center; gap: var(--sp-3);">
            <input type="range" id="setting-checkin" min="2" max="15" step="1" value="${settings.checkinInterval}" />
            <span id="setting-checkin-val" style="font-family: var(--font-mono); font-size: var(--fs-sm); color: var(--text-primary); width: 50px;">${settings.checkinInterval} min</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Notification Settings -->
    <div class="card" style="margin-bottom: var(--sp-6);">
      <div class="card-title">Notifications</div>

      <div class="setting-group">
        <div class="setting-row">
          <div>
            <div class="setting-label">Gentle Reminders</div>
            <div class="setting-desc">Show motivational tips during focus sessions</div>
          </div>
          <div class="toggle ${settings.notificationsEnabled ? 'active' : ''}" id="toggle-notifications" role="switch" aria-checked="${settings.notificationsEnabled}"></div>
        </div>
      </div>

      <div class="setting-group">
        <div class="setting-row">
          <div>
            <div class="setting-label">Browser Notifications</div>
            <div class="setting-desc">Send reminders as system notifications</div>
          </div>
          <button class="btn btn-secondary btn-sm" id="btn-request-notif">
            ${'Notification' in window && Notification.permission === 'granted' ? '✅ Granted' : 'Enable'}
          </button>
        </div>
      </div>
    </div>

    <!-- Privacy & Data -->
    <div class="card" style="margin-bottom: var(--sp-6);">
      <div class="card-title">Privacy & Data</div>

      <div style="padding: var(--sp-4); background: rgba(52, 211, 153, 0.08); border-radius: var(--radius-md); border-left: 3px solid var(--accent-emerald); margin-bottom: var(--sp-4);">
        <div style="font-size: var(--fs-sm); font-weight: 600; color: var(--accent-emerald); margin-bottom: 4px;">🛡️ Your Privacy is Protected</div>
        <div style="font-size: var(--fs-sm); color: var(--text-secondary); line-height: 1.6;">
          All data is stored locally in your browser's localStorage. Nothing is sent to any server.
          No tracking, no analytics, no cookies — just you and your focus.
        </div>
      </div>

      <div class="setting-group">
        <div class="setting-row">
          <div>
            <div class="setting-label">Export Data</div>
            <div class="setting-desc">Download your session history as JSON</div>
          </div>
          <button class="btn btn-secondary btn-sm" id="btn-export">📥 Export</button>
        </div>
      </div>

      <div class="setting-group">
        <div class="setting-row">
          <div>
            <div class="setting-label">Clear All Data</div>
            <div class="setting-desc">Permanently delete all session history and settings</div>
          </div>
          <button class="btn btn-danger btn-sm" id="btn-clear">🗑️ Clear</button>
        </div>
      </div>
    </div>

    <!-- About -->
    <div class="card">
      <div class="card-title">About QuantumFocus</div>
      <div style="padding: var(--sp-2) 0; font-size: var(--fs-sm); color: var(--text-secondary); line-height: 1.8;">
        <p><strong style="color: var(--text-primary);">QuantumFocus v1.0</strong></p>
        <p>A quantum-inspired, privacy-first anti-distraction system.</p>
        <p>Uses probabilistic superposition models to gently guide your focus without intrusive monitoring.</p>
        <p style="margin-top: var(--sp-3); color: var(--text-muted);">Built with ❤️ for students everywhere.</p>
      </div>
    </div>
  `;

    // Wire range sliders
    _wireRange('setting-focus', 'setting-focus-val', 'focusDuration', settings, sessionManager);
    _wireRange('setting-short-break', 'setting-short-break-val', 'shortBreak', settings, sessionManager);
    _wireRange('setting-long-break', 'setting-long-break-val', 'longBreak', settings, sessionManager);
    _wireRange('setting-checkin', 'setting-checkin-val', 'checkinInterval', settings, sessionManager);

    // Toggle notifications
    document.getElementById('toggle-notifications')?.addEventListener('click', (e) => {
        const toggle = e.currentTarget;
        const isActive = toggle.classList.toggle('active');
        settings.notificationsEnabled = isActive;
        sessionManager.saveSettings(settings);
    });

    // Request browser notifications
    document.getElementById('btn-request-notif')?.addEventListener('click', async () => {
        if ('Notification' in window) {
            const perm = await Notification.requestPermission();
            if (perm === 'granted') {
                showToast('Browser notifications enabled!', 'success');
                document.getElementById('btn-request-notif').textContent = '✅ Granted';
            }
        }
    });

    // Export
    document.getElementById('btn-export')?.addEventListener('click', () => {
        const data = {
            sessions: sessionManager.getSessions(),
            settings: sessionManager.getSettings(),
            exportedAt: new Date().toISOString(),
        };
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `quantumfocus-export-${Date.now()}.json`;
        a.click();
        URL.revokeObjectURL(url);
        showToast('Data exported successfully!', 'success');
    });

    // Clear
    document.getElementById('btn-clear')?.addEventListener('click', () => {
        if (confirm('Are you sure you want to clear all data? This cannot be undone.')) {
            sessionManager.clearHistory();
            localStorage.removeItem('qf_settings');
            showToast('All data cleared.', 'info');
            renderSettings(container, sessionManager);
        }
    });
}

function _wireRange(inputId, labelId, key, settings, sessionManager) {
    const input = document.getElementById(inputId);
    const label = document.getElementById(labelId);
    if (!input || !label) return;

    input.addEventListener('input', () => {
        const val = parseInt(input.value, 10);
        label.textContent = `${val} min`;
        settings[key] = val;
        sessionManager.saveSettings(settings);
    });
}
