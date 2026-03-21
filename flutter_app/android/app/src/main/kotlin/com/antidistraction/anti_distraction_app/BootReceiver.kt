package com.antidistraction.anti_distraction_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * BootReceiver
 *
 * Catches BOOT_COMPLETED and restarts AppMonitorService if a focus session
 * was marked as active before the device was rebooted.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences(
            FocusAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE
        )

        val sessionActive = prefs.getBoolean(
            FocusAccessibilityService.KEY_SESSION_ACTIVE, false
        )
        val sessionEndMs = prefs.getLong(
            FocusAccessibilityService.KEY_SESSION_END, 0L
        )

        // Only restart if session is still valid (hasn't expired)
        val sessionStillValid = sessionActive &&
            (sessionEndMs == 0L || System.currentTimeMillis() < sessionEndMs)

        if (sessionStillValid) {
            val serviceIntent = Intent(context, AppMonitorService::class.java).apply {
                action = AppMonitorService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
