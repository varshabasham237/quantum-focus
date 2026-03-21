package com.antidistraction.anti_distraction_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONArray

/**
 * AppMonitorService
 *
 * Foreground service that keeps the focus session alive in the background.
 * - Shows a persistent "Focus Mode Active" notification
 * - Polls foreground app using UsageStatsManager every 1s as a backup to the
 *   Accessibility Service (for devices / scenarios where accessibility is unavailable)
 * - Auto-stops when the session expires
 */
class AppMonitorService : Service() {

    companion object {
        const val CHANNEL_ID          = "focus_monitor_channel"
        const val NOTIFICATION_ID     = 1001
        const val ACTION_START        = "ACTION_START_MONITORING"
        const val ACTION_STOP         = "ACTION_STOP_MONITORING"
        private const val POLL_INTERVAL_MS = 1500L
    }

    private lateinit var prefs: SharedPreferences
    private val handler = Handler(Looper.getMainLooper())
    private var monitorRunnable: Runnable? = null
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(FocusAccessibilityService.PREFS_NAME, MODE_PRIVATE)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopMonitoring()
                return START_NOT_STICKY
            }
            else -> startMonitoring()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopMonitoring()
        super.onDestroy()
    }

    // ── Start monitoring ───────────────────────────────────────────────────
    private fun startMonitoring() {
        if (isRunning) return
        isRunning = true
        startForeground(NOTIFICATION_ID, buildNotification())

        monitorRunnable = object : Runnable {
            override fun run() {
                if (!isRunning) return

                // Check session expiry
                val endMs = prefs.getLong(FocusAccessibilityService.KEY_SESSION_END, 0L)
                if (endMs > 0 && System.currentTimeMillis() > endMs) {
                    // Session expired — deactivate and stop
                    prefs.edit()
                        .putBoolean(FocusAccessibilityService.KEY_SESSION_ACTIVE, false)
                        .apply()
                    stopMonitoring()
                    return
                }

                // UsageStats backup check (complements AccessibilityService)
                val foregroundPkg = getForegroundPackage()
                if (foregroundPkg != null && isFocusSessionActive()) {
                    if (isBlocked(foregroundPkg) &&
                        foregroundPkg != "com.antidistraction.anti_distraction_app") {
                        val intent = Intent(applicationContext, BlockOverlayActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            putExtra(BlockOverlayActivity.EXTRA_BLOCKED_PACKAGE, foregroundPkg)
                        }
                        startActivity(intent)
                    }
                }

                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
        handler.post(monitorRunnable!!)
    }

    private fun stopMonitoring() {
        isRunning = false
        monitorRunnable?.let { handler.removeCallbacks(it) }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ── Foreground app detection ───────────────────────────────────────────
    private fun getForegroundPackage(): String? {
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val endTime = System.currentTimeMillis()
            val beginTime = endTime - 5000L
            val stats = usm.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY, beginTime, endTime
            )
            stats?.maxByOrNull { it.lastTimeUsed }?.packageName
        } catch (e: Exception) {
            null
        }
    }

    private fun isFocusSessionActive(): Boolean =
        prefs.getBoolean(FocusAccessibilityService.KEY_SESSION_ACTIVE, false)

    private fun isBlocked(packageName: String): Boolean {
        return try {
            val raw = prefs.getString(FocusAccessibilityService.KEY_BLOCKLIST, "[]") ?: "[]"
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                if (arr.getString(i) == packageName) return true
            }
            false
        } catch (e: Exception) { false }
    }

    // ── Notification ───────────────────────────────────────────────────────
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Focus Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps your focus session running in the background"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, AppMonitorService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPi = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = Intent(this, MainActivity::class.java)
        val openPi = PendingIntent.getActivity(
            this, 1, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("🛡️ Focus Mode Active")
            .setContentText("Distracting apps are blocked. Stay focused!")
            .setContentIntent(openPi)
            .addAction(android.R.drawable.ic_delete, "End Session", stopPi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
