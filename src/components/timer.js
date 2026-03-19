/**
 * Focus Timer component
 */

export function renderTimer(container, sessionManager) {
    const session = sessionManager.currentSession;
    const settings = sessionManager.getSettings();
    const isRunning = !!session;
    const phase = session ? session.phase : 'focus';

    const remaining = session ? session.remaining : settings.focusDuration * 60;
    const total = session ? session.totalFocusSec : settings.focusDuration * 60;
    const mins = Math.floor(remaining / 60);
    const secs = remaining % 60;
    const progress = total > 0 ? (total - remaining) / total : 0;

    const circumference = 2 * Math.PI * 120;
    const dashOffset = circumference * (1 - progress);

    const quantum = sessionManager.getQuantum();
    const state = quantum.getState();

    container.innerHTML = `
    <div class="page-header">
      <h1>⏱️ Focus Timer</h1>
      <p>Quantum-guided Pomodoro with adaptive check-ins</p>
    </div>

    <div class="timer-container">
      <div class="timer-ring-wrapper">
        <svg viewBox="0 0 260 260">
          <defs>
            <linearGradient id="timerGrad" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stop-color="#8b5cf6"/>
              <stop offset="100%" stop-color="#22d3ee"/>
            </linearGradient>
          </defs>
          <circle class="timer-ring-bg" cx="130" cy="130" r="120"/>
          <circle class="timer-ring-progress" cx="130" cy="130" r="120"
            stroke-dasharray="${circumference}"
            stroke-dashoffset="${dashOffset}" />
        </svg>
        <div class="timer-center">
          <div class="timer-time" id="timer-display">${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}</div>
          <div class="timer-phase" id="timer-phase">${phase === 'focus' ? '🎯 Focus' : '☕ Break'}</div>
        </div>
      </div>

      <div class="timer-controls" id="timer-controls">
        ${!isRunning
            ? `<button class="btn btn-primary btn-lg" id="timer-start">
               <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
               Start Session
             </button>`
            : `<button class="btn btn-secondary" id="timer-pause">
               <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>
               Pause
             </button>
             <button class="btn btn-danger" id="timer-end">
               <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/></svg>
               End Session
             </button>`
        }
      </div>

      <!-- Quantum state mini-display -->
      <div class="card" style="width: 100%; max-width: 500px; margin-top: var(--sp-4);">
        <div class="card-title">Live Quantum State</div>
        <div class="prob-bars">
          <div class="prob-bar-row">
            <span class="prob-bar-label">🎯 Focused</span>
            <div class="prob-bar-track">
              <div class="prob-bar-fill focused" id="timer-prob-focused" style="width: ${state.focused * 100}%"></div>
            </div>
            <span class="prob-bar-value" id="timer-val-focused">${Math.round(state.focused * 100)}%</span>
          </div>
          <div class="prob-bar-row">
            <span class="prob-bar-label">🌊 Drifting</span>
            <div class="prob-bar-track">
              <div class="prob-bar-fill drifting" id="timer-prob-drifting" style="width: ${state.drifting * 100}%"></div>
            </div>
            <span class="prob-bar-value" id="timer-val-drifting">${Math.round(state.drifting * 100)}%</span>
          </div>
          <div class="prob-bar-row">
            <span class="prob-bar-label">🌀 Distracted</span>
            <div class="prob-bar-track">
              <div class="prob-bar-fill distracted" id="timer-prob-distracted" style="width: ${state.distracted * 100}%"></div>
            </div>
            <span class="prob-bar-value" id="timer-val-distracted">${Math.round(state.distracted * 100)}%</span>
          </div>
        </div>
      </div>
    </div>
  `;

    // Wire controls
    const startBtn = document.getElementById('timer-start');
    const pauseBtn = document.getElementById('timer-pause');
    const endBtn = document.getElementById('timer-end');

    if (startBtn) {
        startBtn.addEventListener('click', () => {
            sessionManager.start();
            renderTimer(container, sessionManager);
            _startLiveUpdates(container, sessionManager);
        });
    }

    if (pauseBtn) {
        let paused = false;
        pauseBtn.addEventListener('click', () => {
            if (!paused) {
                sessionManager.pause();
                pauseBtn.innerHTML = `
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
          Resume`;
                paused = true;
            } else {
                sessionManager.resume();
                pauseBtn.innerHTML = `
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>
          Pause`;
                paused = false;
            }
        });
    }

    if (endBtn) {
        endBtn.addEventListener('click', () => {
            sessionManager.end();
            renderTimer(container, sessionManager);
        });
    }

    // If already running, start live updates
    if (isRunning) {
        _startLiveUpdates(container, sessionManager);
    }
}

let _liveInterval = null;

function _startLiveUpdates(container, sessionManager) {
    if (_liveInterval) clearInterval(_liveInterval);

    _liveInterval = setInterval(() => {
        const session = sessionManager.currentSession;
        if (!session) {
            clearInterval(_liveInterval);
            _liveInterval = null;
            return;
        }

        // Update timer display
        const timerDisplay = document.getElementById('timer-display');
        const timerPhase = document.getElementById('timer-phase');
        if (timerDisplay) {
            const mins = Math.floor(session.remaining / 60);
            const secs = session.remaining % 60;
            timerDisplay.textContent = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        }
        if (timerPhase) {
            timerPhase.textContent = session.phase === 'focus' ? '🎯 Focus' : '☕ Break';
        }

        // Update progress ring
        const circumference = 2 * Math.PI * 120;
        const progress = session.totalFocusSec > 0
            ? (session.totalFocusSec - session.remaining) / session.totalFocusSec
            : 0;
        const ring = container.querySelector('.timer-ring-progress');
        if (ring) {
            ring.setAttribute('stroke-dashoffset', circumference * (1 - progress));
        }

        // Update quantum bars
        const state = sessionManager.getQuantum().getState();
        const fb = document.getElementById('timer-prob-focused');
        const db = document.getElementById('timer-prob-drifting');
        const xb = document.getElementById('timer-prob-distracted');
        const fv = document.getElementById('timer-val-focused');
        const dv = document.getElementById('timer-val-drifting');
        const xv = document.getElementById('timer-val-distracted');

        if (fb) fb.style.width = `${state.focused * 100}%`;
        if (db) db.style.width = `${state.drifting * 100}%`;
        if (xb) xb.style.width = `${state.distracted * 100}%`;
        if (fv) fv.textContent = `${Math.round(state.focused * 100)}%`;
        if (dv) dv.textContent = `${Math.round(state.drifting * 100)}%`;
        if (xv) xv.textContent = `${Math.round(state.distracted * 100)}%`;
    }, 500);
}

// Cleanup on page navigation
export function cleanupTimer() {
    if (_liveInterval) {
        clearInterval(_liveInterval);
        _liveInterval = null;
    }
}
