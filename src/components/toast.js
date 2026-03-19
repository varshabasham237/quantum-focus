/**
 * Toast notification component
 */

let toastContainer = null;

function getContainer() {
    if (!toastContainer) {
        toastContainer = document.getElementById('toast-container');
    }
    return toastContainer;
}

const ICONS = {
    info: '💡',
    success: '✅',
    warning: '⚠️',
    error: '❌',
};

/**
 * Show a toast notification.
 * @param {string} message
 * @param {'info'|'success'|'warning'|'error'} type
 * @param {number} durationMs
 */
export function showToast(message, type = 'info', durationMs = 5000) {
    const container = getContainer();
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.innerHTML = `
    <span class="toast-icon">${ICONS[type] || ICONS.info}</span>
    <div class="toast-body">
      <div class="toast-title">${type === 'warning' ? 'Gentle Reminder' : type === 'success' ? 'Well Done!' : 'QuantumFocus'}</div>
      <div class="toast-msg">${message}</div>
    </div>
  `;

    container.appendChild(toast);

    setTimeout(() => {
        toast.classList.add('leaving');
        setTimeout(() => toast.remove(), 300);
    }, durationMs);
}
