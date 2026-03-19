/**
 * Analytics component
 */

export function renderAnalytics(container, sessionManager) {
    const weeklyData = sessionManager.getWeeklyData();
    const sessions = sessionManager.getSessions();
    const recentSessions = sessions.slice(0, 10);

    const maxMin = Math.max(...weeklyData.map(d => d.minutes), 1);

    container.innerHTML = `
    <div class="page-header">
      <h1>📊 Focus Analytics</h1>
      <p>Your study patterns analyzed through quantum probability distributions</p>
    </div>

    <!-- Weekly Focus Chart -->
    <div class="card" style="margin-bottom: var(--sp-6);">
      <div class="card-title">7-Day Focus Trend</div>
      <div class="chart-container" id="weekly-chart">
        <div style="display: flex; align-items: flex-end; justify-content: space-around; height: 100%; padding: var(--sp-4) 0;">
          ${weeklyData.map(d => `
            <div style="display: flex; flex-direction: column; align-items: center; gap: var(--sp-2); flex: 1;">
              <span style="font-size: var(--fs-xs); color: var(--text-muted); font-family: var(--font-mono);">${d.minutes}m</span>
              <div style="
                width: 32px;
                height: ${Math.max(4, (d.minutes / maxMin) * 150)}px;
                background: var(--gradient-primary);
                border-radius: var(--radius-sm) var(--radius-sm) 0 0;
                transition: height 0.5s var(--ease);
                position: relative;
                overflow: hidden;
              ">
                <div style="
                  position: absolute;
                  inset: 0;
                  background: linear-gradient(180deg, rgba(255,255,255,0.1), transparent);
                "></div>
              </div>
              <span style="font-size: var(--fs-xs); color: var(--text-secondary); font-weight: 600;">${d.label}</span>
              <span style="font-size: var(--fs-xs); color: var(--text-muted);">${d.date}</span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>

    <div class="grid-2" style="margin-bottom: var(--sp-6);">
      <!-- Weekly Score Distribution -->
      <div class="card">
        <div class="card-title">Weekly Focus Scores</div>
        <div style="padding: var(--sp-4) 0;">
          ${weeklyData.map(d => `
            <div style="display: flex; align-items: center; gap: var(--sp-3); margin-bottom: var(--sp-3);">
              <span style="width: 40px; font-size: var(--fs-xs); color: var(--text-muted); text-align: right;">${d.label}</span>
              <div class="prob-bar-track" style="flex: 1;">
                <div class="prob-bar-fill focused" style="width: ${d.score}%;"></div>
              </div>
              <span style="width: 36px; font-size: var(--fs-xs); font-weight: 600; color: ${d.score >= 70 ? 'var(--accent-emerald)' : d.score >= 40 ? 'var(--accent-amber)' : 'var(--accent-rose)'}; font-family: var(--font-mono);">${d.score}%</span>
            </div>
          `).join('')}
        </div>
      </div>

      <!-- Session Count -->
      <div class="card">
        <div class="card-title">Sessions Per Day</div>
        <div style="padding: var(--sp-4) 0;">
          ${weeklyData.map(d => `
            <div style="display: flex; align-items: center; gap: var(--sp-3); margin-bottom: var(--sp-3);">
              <span style="width: 40px; font-size: var(--fs-xs); color: var(--text-muted); text-align: right;">${d.label}</span>
              <div style="display: flex; gap: 4px; flex: 1;">
                ${Array.from({ length: Math.min(d.sessions, 12) }, () =>
        `<div style="width: 16px; height: 16px; border-radius: 4px; background: var(--gradient-primary); opacity: 0.8;"></div>`
    ).join('')}
                ${d.sessions === 0 ? '<span style="font-size: var(--fs-xs); color: var(--text-muted);">No sessions</span>' : ''}
              </div>
              <span style="width: 24px; font-size: var(--fs-xs); font-weight: 600; color: var(--text-secondary); text-align: right;">${d.sessions}</span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>

    <!-- Session History Table -->
    <div class="card">
      <div class="card-title">Recent Session History</div>
      ${recentSessions.length === 0
            ? `<div class="empty-state">
             <div class="empty-icon">📋</div>
             <p>No sessions recorded yet. Start your first focus session!</p>
           </div>`
            : `<table class="session-table">
             <thead>
               <tr>
                 <th>Date</th>
                 <th>Duration</th>
                 <th>Focus Score</th>
                 <th>Check-ins</th>
                 <th>Phase</th>
               </tr>
             </thead>
             <tbody>
               ${recentSessions.map(s => {
                const date = new Date(s.startTime);
                const scoreColor = s.focusScore >= 70 ? 'var(--accent-emerald)' : s.focusScore >= 40 ? 'var(--accent-amber)' : 'var(--accent-rose)';
                return `
                   <tr>
                     <td>${date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} ${date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}</td>
                     <td>${s.durationMin || 0} min</td>
                     <td style="color: ${scoreColor}; font-weight: 600; font-family: var(--font-mono);">${s.focusScore}%</td>
                     <td>${(s.checkins || []).length}</td>
                     <td style="text-transform: capitalize;">${s.phase || 'focus'}</td>
                   </tr>`;
            }).join('')}
             </tbody>
           </table>`
        }
    </div>
  `;
}
