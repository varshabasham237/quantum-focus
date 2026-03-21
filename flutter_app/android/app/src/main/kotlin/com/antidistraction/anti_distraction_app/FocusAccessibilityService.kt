package com.antidistraction.anti_distraction_app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

/**
 * FocusAccessibilityService
 *
 * Listens for window change events. When the foreground app changes and the new
 * package is in the user's block list (stored in SharedPreferences), it immediately
 * launches BlockOverlayActivity to cover the distracting app.
 *
 * Module 5.3: Also respects the focus_locked flag — when locked, blocking cannot
 * be bypassed even if session_active is temporarily false.
 */
class FocusAccessibilityService : AccessibilityService() {

    companion object {
        const val PREFS_NAME          = "focus_prefs"
        const val KEY_BLOCKLIST       = "blocked_packages"
        const val KEY_SESSION_ACTIVE  = "session_active"
        const val KEY_SESSION_END     = "session_end_ms"
        const val KEY_SWITCH_COUNT    = "switch_count"    // 5.3
        const val KEY_FOCUS_LOCKED    = "focus_locked"    // 5.3

        private const val OWN_PACKAGE = "com.antidistraction.anti_distraction_app"
        private const val MAX_SWITCHES = 3
    }

    private var lastBlockedPackage: String = ""

    override fun onServiceConnected() {
        super.onServiceConnected()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // Skip system UI, launcher, and our own app
        if (packageName == OWN_PACKAGE ||
            packageName == "com.android.systemui" ||
            packageName == "com.android.launcher3" ||
            packageName.startsWith("com.google.android.inputmethod")
        ) return

        // Only block when a focus session is active OR focus is locked (5.3)
        if (!shouldBlock()) return

        if (isBlocked(packageName)) {
            if (packageName == lastBlockedPackage) return
            lastBlockedPackage = packageName
            showBlockOverlay(packageName)
        } else {
            if (packageName != lastBlockedPackage) lastBlockedPackage = ""
        }
    }

    override fun onInterrupt() {}

    // ── Session / Lock check (5.3) ─────────────────────────────────────────
    /**
     * Returns true if blocking should be enforced.
     * Blocking is enforced if:
     *  1. session_active == true, OR
     *  2. focus_locked == true (user hit max switches — cannot turn off focus)
     * In both cases we also check that the session hasn't expired.
     */
    private fun shouldBlock(): Boolean {
        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val sessionActive = prefs.getBoolean(KEY_SESSION_ACTIVE, false)
        val focusLocked   = prefs.getBoolean(KEY_FOCUS_LOCKED, false)
        val endMs         = prefs.getLong(KEY_SESSION_END, 0L)

        // Check expiry
        if (endMs > 0 && System.currentTimeMillis() > endMs) {
            // Session expired — clear everything
            prefs.edit()
                .putBoolean(KEY_SESSION_ACTIVE, false)
                .putBoolean(KEY_FOCUS_LOCKED, false)
                .putInt(KEY_SWITCH_COUNT, 0)
                .apply()
            return false
        }

        return sessionActive || focusLocked
    }

    // ── Blocklist check ────────────────────────────────────────────────────
    private fun isBlocked(packageName: String): Boolean {
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val raw = prefs.getString(KEY_BLOCKLIST, "[]") ?: "[]"
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                if (arr.getString(i) == packageName) return true
            }
            false
        } catch (e: Exception) { false }
    }

    // ── Launch block overlay ───────────────────────────────────────────────
    private fun showBlockOverlay(blockedPackage: String) {
        val intent = Intent(applicationContext, BlockOverlayActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(BlockOverlayActivity.EXTRA_BLOCKED_PACKAGE, blockedPackage)
        }
        applicationContext.startActivity(intent)
    }
}
