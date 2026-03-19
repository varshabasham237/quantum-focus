/**
 * Dashboard component
 */

export function renderDashboard(container, sessionManager) {
    const stats = sessionManager.getTodayStats();
    const quantum = sessionManager.getQuantum();
    const state = quantum.getState();
    const prediction = quantum.predict();
    const dominant = quantum.getDominant();

    container.innerHTML = `
    <div class="page-header">
      <h1>⚛️ Quantum Dashboard</h1>
      <p>Your attention state, visualized through quantum probability amplitudes</p>
    </div>

    <div class="grid-2" style="margin-bottom: var(--sp-6);">
      <!-- Quantum Orb -->
      <div class="card" id="orb-card">
        <div class="card-title">Quantum Focus State</div>
        <div class="quantum-orb-container">
          <div class="quantum-orb" id="dashboard-orb">
            <div class="ring ring-1"></div>
            <div class="ring ring-2"></div>
            <div class="ring ring-3"></div>
            <div class="orb-inner"></div>
            <div class="state-label">
              <span class="state-name">${dominant}</span>
              <span class="state-pct">${Math.round(state[dominant] * 100)}%</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Probability Distribution -->
      <div class="card">
        <div class="card-title">Probability Amplitudes</div>
        <div class="prob-bars" style="margin-top: var(--sp-4);">
          <div class="prob-bar-row">
            <span class="prob-bar-label">🎯 Focused</span>
            <div class="prob-bar-track">
              <div class="prob-bar-fill focused" style="width: ${state.focused * 100}%"></div>
            </div>
            <span class="prob-bar-value">${Math.round(state.focused * 100)}%</span>
          </div>
          <div class="prob-bar-row">
            <span class="prob-bar-label">🌊 Drifting</span>
            <div class="prob-bar-track">
              <div class="prob-bar-fill drifting" style="width: ${state.drifting * 100}%"></div>
            </div>
            <span class="prob-bar-value">${Math.round(state.drifting * 100)}%</span>
          </div>
          <div class="prob-bar-row">
            <span class="prob-bar-label">🌀 Distracted</span>
            <div class="prob-bar-track">
              <div class="prob-bar-fill distracted" style="width: ${state.distracted * 100}%"></div>
            </div>
            <span class="prob-bar-value">${Math.round(state.distracted * 100)}%</span>
          </div>
        </div>

        <div style="margin-top: var(--sp-6); padding: var(--sp-4); background: var(--bg-glass); border-radius: var(--radius-md); border-left: 3px solid ${prediction.urgency === 'high' ? 'var(--accent-rose)' : prediction.urgency === 'medium' ? 'var(--accent-amber)' : 'var(--accent-emerald)'};">
          <div style="font-size: var(--fs-sm); font-weight: 600; color: var(--text-primary); margin-bottom: 4px;">Quantum Prediction</div>
          <div style="font-size: var(--fs-sm); color: var(--text-secondary); line-height: 1.5;">${prediction.message}</div>
        </div>
      </div>
    </div>

    <!-- Stats -->
    <div class="stat-grid" style="margin-bottom: var(--sp-6);">
      <div class="card stat-card">
        <div class="stat-icon">📚</div>
        <div class="stat-value">${stats.sessionsCount}</div>
        <div class="stat-label">Sessions Today</div>
      </div>
      <div class="card stat-card">
        <div class="stat-icon">⏱️</div>
        <div class="stat-value">${stats.totalMinutes}<span style="font-size: var(--fs-lg); -webkit-text-fill-color: var(--text-secondary);">m</span></div>
        <div class="stat-label">Total Focus Time</div>
      </div>
      <div class="card stat-card">
        <div class="stat-icon">🎯</div>
        <div class="stat-value">${stats.averageScore}<span style="font-size: var(--fs-lg); -webkit-text-fill-color: var(--text-secondary);">%</span></div>
        <div class="stat-label">Average Focus Score</div>
      </div>
      <div class="card stat-card">
        <div class="stat-icon">🔥</div>
        <div class="stat-value">${stats.streak}</div>
        <div class="stat-label">Day Streak</div>
      </div>
    </div>

    <!-- Quick Start -->
    <div class="card" style="text-align: center;">
      <div style="font-size: var(--fs-xl); font-weight: 700; margin-bottom: var(--sp-2);">Ready to focus?</div>
      <p style="color: var(--text-secondary); margin-bottom: var(--sp-6); font-size: var(--fs-md);">
        Start a quantum-guided study session. Your focus state will evolve and adapt.
      </p>
      <button class="btn btn-primary btn-lg" id="dashboard-start-btn">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
        Start Focus Session
      </button>
    </div>
  `;

    // Wire start button
    document.getElementById('dashboard-start-btn')?.addEventListener('click', () => {
        // Navigate to timer page
        window.location.hash = '#timer';
        window.dispatchEvent(new CustomEvent('qf-start-session'));
    });
}
