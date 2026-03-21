package com.antidistraction.anti_distraction_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val PERMISSION_CHANNEL = "com.quantumfocus/permissions"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PERMISSION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // ── Permission Checks ──────────────────────────────────────
                "checkUsageAccess" -> result.success(hasUsageAccess())
                "checkOverlayPermission" -> result.success(hasOverlayPermission())
                "checkAccessibilityEnabled" -> {
                    val serviceClass = call.argument<String>("serviceClass") ?: ""
                    result.success(isAccessibilityServiceEnabled(serviceClass))
                }

                // ── Settings Deep-Links ────────────────────────────────────
                "openUsageAccessSettings" -> {
                    openUsageAccessSettings()
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(null)
                }

                // ── App Monitor Service ────────────────────────────────────
                "startMonitorService" -> {
                    startAppMonitorService()
                    result.success(null)
                }
                "stopMonitorService" -> {
                    stopAppMonitorService()
                    result.success(null)
                }

                // ── Installed Apps List ────────────────────────────────────
                "getInstalledApps" -> {
                    result.success(getInstalledApps())
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── Usage Access Check ───────────────────────────────────────────────
    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(), packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(), packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) { false }
    }

    // ── Overlay Permission Check ─────────────────────────────────────────
    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    // ── Accessibility Service Check ──────────────────────────────────────
    private fun isAccessibilityServiceEnabled(serviceClass: String): Boolean {
        if (serviceClass.isBlank()) return false
        return try {
            val enabledServices = Settings.Secure.getString(
                contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            val splitter = TextUtils.SimpleStringSplitter(':')
            splitter.setString(enabledServices)
            while (splitter.hasNext()) {
                if (splitter.next().equals(serviceClass, ignoreCase = true)) return true
            }
            false
        } catch (e: Exception) { false }
    }

    // ── Settings Deep-Link Launchers ─────────────────────────────────────
    private fun openUsageAccessSettings() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }

    private fun openOverlaySettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"))
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        }
        startActivity(intent.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) })
    }

    // ── App Monitor Service Control ──────────────────────────────────────
    private fun startAppMonitorService() {
        val intent = Intent(this, AppMonitorService::class.java).apply {
            action = AppMonitorService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAppMonitorService() {
        val intent = Intent(this, AppMonitorService::class.java).apply {
            action = AppMonitorService.ACTION_STOP
        }
        startService(intent)
    }

    // ── Installed Apps Listing ────────────────────────────────────────────
    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, String>>()

        // System + core packages to skip
        val skipPackages = setOf(
            "com.antidistraction.anti_distraction_app",
            "com.android.systemui",
            "com.android.launcher3",
            "com.android.settings",
            "com.google.android.inputmethod.latin"
        )

        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolvedApps = pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)

        for (resolveInfo in resolvedApps) {
            val pkgName = resolveInfo.activityInfo.packageName
            if (pkgName in skipPackages) continue
            val label = resolveInfo.loadLabel(pm).toString()
            apps.add(mapOf("package_name" to pkgName, "app_name" to label))
        }

        return apps.sortedBy { it["app_name"] }
    }
}
