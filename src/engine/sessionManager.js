/**
 * SessionManager
 * Manages study sessions with Pomodoro-style intervals and quantum-adaptive breaks.
 * Syncs with Flask backend via API, falls back to localStorage when offline.
 */

import { QuantumFocusState } from './quantumState.js';
import * as api from './api.js';

const STORAGE_KEY = 'qf_sessions';
const SETTINGS_KEY = 'qf_settings';

export class SessionManager {
    constructor() {
        this.quantum = new QuantumFocusState();
        this.sessions = this._loadSessions();
        this.currentSession = null;
        this._tickTimer = null;
        this._evolveTimer = null;
        this._checkinTimer = null;
        this.onTick = null;        // callback(remainingSec, totalSec)
        this.onPhaseChange = null;  // callback(phase: 'focus'|'break')
        this.onCheckin = null;      // callback()
        this.onComplete = null;     // callback(session)
        this.onQuantumUpdate = null; // callback(state)
        this._useBackend = true;    // try backend first

        // Sync quantum state from backend on init
        this._syncQuantumFromBackend();
    }

    async _syncQuantumFromBackend() {
        const data = await api.getQuantumState();
        if (data && data.state) {
            this.quantum.probs = [data.state.focused, data.state.drifting, data.state.distracted];
        } else {
            this._useBackend = false;
            console.log('[SessionManager] Backend unavailable, using localStorage mode');
        }
    }

    getSettings() {
        const raw = localStorage.getItem(SETTINGS_KEY);
        const defaults = {
            focusDuration: 25,
            shortBreak: 5,
            longBreak: 15,
            sessionsBeforeLong: 4,
            notificationsEnabled: true,
            soundEnabled: true,
            checkinInterval: 5,
        };
        if (!raw) return defaults;
        try { return { ...defaults, ...JSON.parse(raw) }; }
        catch { return defaults; }
    }

    saveSettings(settings) {
        localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
        if (this._useBackend) {
            api.updateSettings(settings);
        }
    }

    /** Start a new focus session */
    start() {
        const settings = this.getSettings();
        const focusSec = settings.focusDuration * 60;
        const sessionId = Date.now();

        this.currentSession = {
            id: sessionId,
            startTime: Date.now(),
            endTime: null,
            phase: 'focus',
            totalFocusSec: focusSec,
            remaining: focusSec,
            pomodorosCompleted: 0,
            checkins: [],
            focusScore: 0,
        };

        this.quantum.reset();

        // Sync to backend
        if (this._useBackend) {
            api.startSession(sessionId, this.currentSession.startTime / 1000);
            api.resetQuantum();
        }

        this._startCountdown();
        this._startEvolution();
        this._scheduleCheckin();

        return this.currentSession;
    }

    /** Pause the timer */
    pause() {
        this._clearTimers();
    }

    /** Resume the timer */
    resume() {
        if (!this.currentSession) return;
        this._startCountdown();
        this._startEvolution();
        this._scheduleCheckin();
    }

    /** End the session early or on completion */
    end() {
        this._clearTimers();
        if (!this.currentSession) return null;

        this.currentSession.endTime = Date.now();
        this.currentSession.focusScore = this.quantum.score();

        const elapsed = (this.currentSession.endTime - this.currentSession.startTime) / 1000;
        const session = {
            ...this.currentSession,
            durationMin: Math.round(elapsed / 60),
        };

        this.sessions.unshift(session);
        if (this.sessions.length > 50) this.sessions.length = 50;
        this._saveSessions();

        // Sync to backend
        if (this._useBackend) {
            api.endSession(
                session.id,
                session.endTime / 1000,
                session.durationMin,
                session.phase,
                session.pomodorosCompleted,
            );
        }

        const result = { ...session };
        this.currentSession = null;
        if (this.onComplete) this.onComplete(result);
        return result;
    }

    /** Switch to break phase */
    startBreak() {
        this._clearTimers();
        if (!this.currentSession) return;

        const settings = this.getSettings();
        this.currentSession.pomodorosCompleted++;
        const isLong = this.currentSession.pomodorosCompleted % settings.sessionsBeforeLong === 0;
        const breakSec = (isLong ? settings.longBreak : settings.shortBreak) * 60;

        this.currentSession.phase = 'break';
        this.currentSession.remaining = breakSec;
        this.currentSession.totalFocusSec = breakSec;

        if (this.onPhaseChange) this.onPhaseChange('break');
        this._startCountdown();
    }

    /** Switch back to focus after break */
    startFocusPhase() {
        this._clearTimers();
        if (!this.currentSession) return;

        const settings = this.getSettings();
        const focusSec = settings.focusDuration * 60;

        this.currentSession.phase = 'focus';
        this.currentSession.remaining = focusSec;
        this.currentSession.totalFocusSec = focusSec;

        if (this.onPhaseChange) this.onPhaseChange('focus');
        this._startCountdown();
        this._startEvolution();
        this._scheduleCheckin();
    }

    /** Record a check-in observation */
    recordCheckin(observation) {
        if (!this.currentSession) return;
        this.quantum.collapse(observation);
        this.currentSession.checkins.push({
            time: Date.now(),
            observation,
            state: this.quantum.getState(),
        });

        // Sync to backend
        if (this._useBackend) {
            api.collapseQuantum(observation, this.currentSession.id);
        }

        if (this.onQuantumUpdate) this.onQuantumUpdate(this.quantum.getState());
        this._scheduleCheckin();
    }

    /** Get the quantum engine */
    getQuantum() { return this.quantum; }

    /** Get all past sessions */
    getSessions() { return this.sessions; }

    /** Clear all history */
    clearHistory() {
        this.sessions = [];
        this._saveSessions();
        if (this._useBackend) {
            api.clearSessions();
        }
    }

    /** Get today's stats */
    getTodayStats() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const todayMs = today.getTime();

        const todaySessions = this.sessions.filter(s => s.startTime >= todayMs);
        const totalMin = todaySessions.reduce((sum, s) => sum + (s.durationMin || 0), 0);
        const avgScore = todaySessions.length
            ? Math.round(todaySessions.reduce((sum, s) => sum + (s.focusScore || 0), 0) / todaySessions.length)
            : 0;

        let streak = 0;
        const dayMs = 86400000;
        let checkDate = todayMs;
        while (true) {
            const hasSessions = this.sessions.some(s =>
                s.startTime >= checkDate && s.startTime < checkDate + dayMs
            );
            if (hasSessions) {
                streak++;
                checkDate -= dayMs;
            } else {
                break;
            }
        }

        return {
            sessionsCount: todaySessions.length,
            totalMinutes: totalMin,
            averageScore: avgScore,
            streak,
        };
    }

    /** Get last 7 days data for analytics */
    getWeeklyData() {
        const days = [];
        const dayMs = 86400000;
        const now = new Date();
        now.setHours(0, 0, 0, 0);

        for (let i = 6; i >= 0; i--) {
            const dayStart = now.getTime() - i * dayMs;
            const dayEnd = dayStart + dayMs;
            const daySessions = this.sessions.filter(s =>
                s.startTime >= dayStart && s.startTime < dayEnd
            );
            const totalMin = daySessions.reduce((sum, s) => sum + (s.durationMin || 0), 0);
            const avgScore = daySessions.length
                ? Math.round(daySessions.reduce((sum, s) => sum + (s.focusScore || 0), 0) / daySessions.length)
                : 0;

            const date = new Date(dayStart);
            days.push({
                label: date.toLocaleDateString('en-US', { weekday: 'short' }),
                date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                sessions: daySessions.length,
                minutes: totalMin,
                score: avgScore,
            });
        }
        return days;
    }

    /* ---- Private ---- */

    _startCountdown() {
        this._tickTimer = setInterval(() => {
            if (!this.currentSession) return;
            this.currentSession.remaining--;

            if (this.onTick) {
                this.onTick(this.currentSession.remaining, this.currentSession.totalFocusSec);
            }

            if (this.currentSession.remaining <= 0) {
                this._clearTimers();
                if (this.currentSession.phase === 'focus') {
                    this.startBreak();
                } else {
                    this.startFocusPhase();
                }
            }
        }, 1000);
    }

    _startEvolution() {
        this._evolveTimer = setInterval(() => {
            this.quantum.evolve(0.5);
            if (this._useBackend) {
                api.evolveQuantum(0.5);
            }
            if (this.onQuantumUpdate) this.onQuantumUpdate(this.quantum.getState());
        }, 30000);
    }

    _scheduleCheckin() {
        if (this._checkinTimer) clearTimeout(this._checkinTimer);
        const settings = this.getSettings();

        const baseMs = settings.checkinInterval * 60 * 1000;
        const jitter = (Math.random() - 0.5) * 0.6 * baseMs;
        const delay = Math.max(30000, baseMs + jitter);

        this._checkinTimer = setTimeout(() => {
            if (this.currentSession && this.currentSession.phase === 'focus') {
                if (this.onCheckin) this.onCheckin();
            }
        }, delay);
    }

    _clearTimers() {
        if (this._tickTimer) { clearInterval(this._tickTimer); this._tickTimer = null; }
        if (this._evolveTimer) { clearInterval(this._evolveTimer); this._evolveTimer = null; }
        if (this._checkinTimer) { clearTimeout(this._checkinTimer); this._checkinTimer = null; }
    }

    _loadSessions() {
        try {
            const raw = localStorage.getItem(STORAGE_KEY);
            return raw ? JSON.parse(raw) : [];
        } catch { return []; }
    }

    _saveSessions() {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(this.sessions));
    }
}
