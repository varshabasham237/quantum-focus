/**
 * API Client — communicates with the Flask backend.
 * Falls back to null if backend is unreachable.
 */

const BASE = '/api';

async function _fetch(path, options = {}) {
    try {
        const res = await fetch(`${BASE}${path}`, {
            headers: { 'Content-Type': 'application/json' },
            ...options,
        });
        if (!res.ok) throw new Error(`${res.status}`);
        return await res.json();
    } catch (err) {
        console.warn(`[API] ${path} failed:`, err.message);
        return null;
    }
}

// ---- Quantum State ----

export async function getQuantumState() {
    return _fetch('/quantum/state');
}

export async function evolveQuantum(dt = 1) {
    return _fetch('/quantum/evolve', {
        method: 'POST',
        body: JSON.stringify({ dt }),
    });
}

export async function collapseQuantum(observation, sessionId = null) {
    return _fetch('/quantum/collapse', {
        method: 'POST',
        body: JSON.stringify({ observation, sessionId }),
    });
}

export async function resetQuantum() {
    return _fetch('/quantum/reset', { method: 'POST' });
}

// ---- Sessions ----

export async function startSession(id, startTime) {
    return _fetch('/sessions', {
        method: 'POST',
        body: JSON.stringify({ action: 'start', id, startTime }),
    });
}

export async function endSession(id, endTime, durationMin, phase, pomodorosCompleted) {
    return _fetch('/sessions', {
        method: 'POST',
        body: JSON.stringify({ action: 'end', id, endTime, durationMin, phase, pomodorosCompleted }),
    });
}

export async function getSessions(limit = 50) {
    return _fetch(`/sessions?limit=${limit}`);
}

export async function clearSessions() {
    return _fetch('/sessions', { method: 'DELETE' });
}

// ---- Stats ----

export async function getTodayStats() {
    return _fetch('/stats/today');
}

export async function getWeeklyData() {
    return _fetch('/stats/weekly');
}

// ---- Settings ----

export async function getSettings() {
    return _fetch('/settings');
}

export async function updateSettings(settings) {
    return _fetch('/settings', {
        method: 'PUT',
        body: JSON.stringify(settings),
    });
}
