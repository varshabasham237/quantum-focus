/**
 * ReminderEngine
 * Provides gentle, non-intrusive reminders via in-app toasts and optional
 * browser notifications. Timing is influenced by quantum state probabilities.
 */

import { showToast } from '../components/toast.js';

const TIPS = {
    focused: [
        '🎯 You\'re in deep focus! Keep up the great work.',
        '✨ Excellent concentration — you\'re making real progress.',
        '🧠 Your focus is strong. Consider noting your key insights.',
    ],
    drifting: [
        '🌊 Feeling a bit scattered? Try re-reading your last sentence.',
        '💡 Quick tip: take 3 deep breaths to refocus.',
        '📝 Consider writing down what you\'re working on to anchor your attention.',
        '🎧 Some lo-fi music might help you get back in the zone.',
    ],
    distracted: [
        '🌀 It looks like your attention has wandered. That\'s okay!',
        '☕ Maybe a 2-minute stretch or a sip of water will help.',
        '🔕 Try silencing your phone to reduce temptation.',
        '🎯 Remind yourself why this study session matters to you.',
        '🧘 Close your eyes, take 5 breaths, then come back refreshed.',
    ],
};

export class ReminderEngine {
    constructor(sessionManager) {
        this.sm = sessionManager;
        this._timer = null;
    }

    /** Start the reminder loop */
    start() {
        this._scheduleNext();
    }

    /** Stop reminders */
    stop() {
        if (this._timer) {
            clearTimeout(this._timer);
            this._timer = null;
        }
    }

    /** Send a reminder based on current quantum state */
    _sendReminder() {
        const quantum = this.sm.getQuantum();
        const state = quantum.getState();
        const dominant = quantum.getDominant();
        const prediction = quantum.predict();

        const tips = TIPS[dominant] || TIPS.drifting;
        const tip = tips[Math.floor(Math.random() * tips.length)];

        const settings = this.sm.getSettings();
        if (settings.notificationsEnabled) {
            showToast(tip, dominant === 'distracted' ? 'warning' : 'info');
        }

        // Also send browser notification if available and enabled
        if (settings.notificationsEnabled && 'Notification' in window && Notification.permission === 'granted') {
            try {
                new Notification('QuantumFocus', {
                    body: tip.replace(/^[^\s]+\s/, ''), // remove emoji prefix
                    icon: '/vite.svg',
                    silent: true,
                });
            } catch (e) {
                // Ignore notification errors
            }
        }

        this._scheduleNext();
    }

    /** Schedule next reminder with quantum-influenced timing */
    _scheduleNext() {
        if (this._timer) clearTimeout(this._timer);

        const quantum = this.sm.getQuantum();
        const state = quantum.getState();

        // Higher distraction probability → more frequent reminders (but still gentle)
        // Base interval: 8-15 minutes
        const baseMinutes = 8 + (1 - state.distracted) * 7;
        const jitter = (Math.random() - 0.5) * 4; // ±2 min jitter
        const intervalMs = Math.max(3 * 60 * 1000, (baseMinutes + jitter) * 60 * 1000);

        this._timer = setTimeout(() => {
            if (this.sm.currentSession && this.sm.currentSession.phase === 'focus') {
                this._sendReminder();
            } else {
                this._scheduleNext();
            }
        }, intervalMs);
    }
}
