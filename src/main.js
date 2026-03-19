/**
 * QuantumFocus — Main Entry Point
 *
 * Initializes the router, quantum engine, and wires everything together.
 */

import './styles/index.css';
import { SessionManager } from './engine/sessionManager.js';
import { ReminderEngine } from './engine/reminderEngine.js';
import { renderDashboard } from './components/dashboard.js';
import { renderTimer, cleanupTimer } from './components/timer.js';
import { renderAnalytics } from './components/analytics.js';
import { renderSettings } from './components/settings.js';
import { showToast } from './components/toast.js';

// ---------- Bootstrap ----------
const sessionManager = new SessionManager();
const reminderEngine = new ReminderEngine(sessionManager);

const pageContainer = document.getElementById('page-container');
const navLinks = document.querySelectorAll('.nav-link');
const checkinOverlay = document.getElementById('checkin-overlay');

// ---------- Particle background ----------
function initParticles() {
    const canvas = document.createElement('canvas');
    canvas.className = 'particles-canvas';
    document.body.appendChild(canvas);

    const ctx = canvas.getContext('2d');
    let particles = [];
    const PARTICLE_COUNT = 50;

    function resize() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    class Particle {
        constructor() {
            this.reset();
        }
        reset() {
            this.x = Math.random() * canvas.width;
            this.y = Math.random() * canvas.height;
            this.size = Math.random() * 2 + 0.5;
            this.speedX = (Math.random() - 0.5) * 0.3;
            this.speedY = (Math.random() - 0.5) * 0.3;
            this.opacity = Math.random() * 0.5 + 0.1;
            this.hue = Math.random() > 0.5 ? 260 : 190; // violet or cyan
        }
        update() {
            this.x += this.speedX;
            this.y += this.speedY;
            if (this.x < 0 || this.x > canvas.width) this.speedX *= -1;
            if (this.y < 0 || this.y > canvas.height) this.speedY *= -1;
        }
        draw() {
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
            ctx.fillStyle = `hsla(${this.hue}, 80%, 65%, ${this.opacity})`;
            ctx.fill();
        }
    }

    particles = Array.from({ length: PARTICLE_COUNT }, () => new Particle());

    function animate() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Draw connection lines between nearby particles
        for (let i = 0; i < particles.length; i++) {
            for (let j = i + 1; j < particles.length; j++) {
                const dx = particles[i].x - particles[j].x;
                const dy = particles[i].y - particles[j].y;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < 150) {
                    ctx.beginPath();
                    ctx.moveTo(particles[i].x, particles[i].y);
                    ctx.lineTo(particles[j].x, particles[j].y);
                    ctx.strokeStyle = `rgba(139, 92, 246, ${0.06 * (1 - dist / 150)})`;
                    ctx.lineWidth = 0.5;
                    ctx.stroke();
                }
            }
        }

        particles.forEach(p => {
            p.update();
            p.draw();
        });

        requestAnimationFrame(animate);
    }

    animate();
}

// ---------- Router ----------
const PAGES = {
    dashboard: (c) => renderDashboard(c, sessionManager),
    timer: (c) => renderTimer(c, sessionManager),
    analytics: (c) => renderAnalytics(c, sessionManager),
    settings: (c) => renderSettings(c, sessionManager),
};

function navigateTo(page) {
    cleanupTimer();
    const renderFn = PAGES[page] || PAGES.dashboard;

    // Add exit animation
    pageContainer.style.animation = 'none';
    /* reflow trick */
    void pageContainer.offsetHeight;
    pageContainer.style.animation = 'pageIn 0.4s var(--ease)';

    renderFn(pageContainer);

    // Update nav active state
    navLinks.forEach(link => {
        link.classList.toggle('active', link.dataset.page === page);
    });
}

function getPageFromHash() {
    const hash = window.location.hash.replace('#', '') || 'dashboard';
    return hash;
}

// Listen for hash changes
window.addEventListener('hashchange', () => {
    navigateTo(getPageFromHash());
});

// Nav click handlers
navLinks.forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        const page = link.dataset.page;
        window.location.hash = `#${page}`;
    });
});

// ---------- Check-in system ----------
sessionManager.onCheckin = () => {
    checkinOverlay.classList.remove('hidden');
};

document.getElementById('checkin-options')?.addEventListener('click', (e) => {
    const btn = e.target.closest('.checkin-btn');
    if (!btn) return;
    const state = btn.dataset.state;
    sessionManager.recordCheckin(state);
    checkinOverlay.classList.add('hidden');

    const prediction = sessionManager.getQuantum().predict();
    if (prediction.urgency !== 'low') {
        showToast(prediction.message, prediction.urgency === 'high' ? 'warning' : 'info');
    }
});

// ---------- Phase change notifications ----------
sessionManager.onPhaseChange = (phase) => {
    if (phase === 'break') {
        showToast('☕ Break time! You\'ve earned a rest.', 'success');
    } else {
        showToast('🎯 Focus phase starting. Let\'s go!', 'info');
    }
    // Re-render timer if on timer page
    if (getPageFromHash() === 'timer') {
        renderTimer(pageContainer, sessionManager);
    }
};

// ---------- Session complete ----------
sessionManager.onComplete = (session) => {
    showToast(`Session complete! Focus score: ${session.focusScore}%`, 'success', 7000);
    reminderEngine.stop();
};

// ---------- Custom event: start session from dashboard ----------
window.addEventListener('qf-start-session', () => {
    setTimeout(() => {
        const startBtn = document.getElementById('timer-start');
        if (startBtn) startBtn.click();
    }, 100);
});

// ---------- Init ----------
initParticles();
navigateTo(getPageFromHash());

// Request notification permission quietly
if ('Notification' in window && Notification.permission === 'default') {
    // We don't auto-request — user must opt in via Settings
}

// Start reminder engine when a session starts
const origStart = sessionManager.start.bind(sessionManager);
sessionManager.start = function () {
    const result = origStart();
    reminderEngine.start();
    return result;
};

console.log('⚛️ QuantumFocus initialized — 100% private, 0% tracking.');
