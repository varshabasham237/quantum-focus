package com.antidistraction.anti_distraction_app

import android.app.Activity
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Button
import android.view.View
import android.graphics.drawable.GradientDrawable

/**
 * BlockOverlayActivity
 *
 * A full-screen overlay shown when the user opens a blocked app during a focus session.
 * Uses TYPE_APPLICATION_OVERLAY (requires SYSTEM_ALERT_WINDOW permission from 5.1).
 * Shows: shield icon, blocked app description, session timer, motivational text, Go Back button.
 */
class BlockOverlayActivity : Activity() {

    companion object {
        const val EXTRA_BLOCKED_PACKAGE = "blocked_package"
    }

    private lateinit var prefs: SharedPreferences
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var timerText: TextView
    private var timerRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        prefs = getSharedPreferences(FocusAccessibilityService.PREFS_NAME, MODE_PRIVATE)

        // Make it full screen with overlay flag
        window.apply {
            setFlags(
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
            )
            addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
        }

        val blockedPkg = intent.getStringExtra(EXTRA_BLOCKED_PACKAGE) ?: "this app"
        val appDisplayName = getAppDisplayName(blockedPkg)

        setContentView(buildBlockUI(appDisplayName))
        startTimer()
    }

    override fun onDestroy() {
        timerRunnable?.let { handler.removeCallbacks(it) }
        super.onDestroy()
    }

    // Prevent back button from dismissing
    override fun onBackPressed() {
        goHome()
    }

    // ── Build UI programmatically ──────────────────────────────────────────
    private fun buildBlockUI(appName: String): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0A0A14"))
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(80, 80, 80, 80)
        }

        // Shield icon (emoji in text view for simplicity)
        val shieldIcon = TextView(this).apply {
            text = "🛡️"
            textSize = 64f
            gravity = Gravity.CENTER
        }
        content.addView(shieldIcon)

        // Spacer
        content.addView(spaceView(48))

        // "Focus Mode Active" label
        val focusLabel = TextView(this).apply {
            text = "FOCUS MODE ACTIVE"
            textSize = 12f
            setTextColor(Color.parseColor("#7B61FF"))
            gravity = Gravity.CENTER
            letterSpacing = 0.3f
        }
        content.addView(focusLabel)

        content.addView(spaceView(16))

        // Blocked app name
        val blockedTitle = TextView(this).apply {
            text = appName
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        content.addView(blockedTitle)

        content.addView(spaceView(8))

        // Subtitle
        val subtitle = TextView(this).apply {
            text = "is blocked during your study session"
            textSize = 15f
            setTextColor(Color.parseColor("#AAAACC"))
            gravity = Gravity.CENTER
        }
        content.addView(subtitle)

        content.addView(spaceView(48))

        // Divider
        content.addView(dividerView())
        content.addView(spaceView(24))

        // Session remaining timer
        val timerLabel = TextView(this).apply {
            text = "Session ends in"
            textSize = 12f
            setTextColor(Color.parseColor("#666688"))
            gravity = Gravity.CENTER
        }
        content.addView(timerLabel)

        content.addView(spaceView(8))

        timerText = TextView(this).apply {
            text = getTimeRemaining()
            textSize = 36f
            setTextColor(Color.parseColor("#00E5A0"))
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        content.addView(timerText)

        content.addView(spaceView(8))

        // Motivational quote
        val motivationText = TextView(this).apply {
            text = "\"Stay focused — your future self will thank you.\""
            textSize = 13f
            setTextColor(Color.parseColor("#555577"))
            gravity = Gravity.CENTER
            setPadding(32, 0, 32, 0)
        }
        content.addView(motivationText)

        content.addView(spaceView(48))

        // Go back button
        val goBackButton = Button(this).apply {
            text = "← Go Back to Studying"
            textSize = 15f
            setTextColor(Color.WHITE)
            background = buildButtonBackground()
            setPadding(64, 32, 64, 32)
            setOnClickListener { goHome() }
        }
        content.addView(goBackButton)

        root.addView(content, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        return root
    }

    // ── Timer ──────────────────────────────────────────────────────────────
    private fun startTimer() {
        timerRunnable = object : Runnable {
            override fun run() {
                if (!isFinishing) {
                    timerText.text = getTimeRemaining()
                    // Check if session ended
                    val endMs = prefs.getLong(FocusAccessibilityService.KEY_SESSION_END, 0L)
                    if (endMs > 0 && System.currentTimeMillis() > endMs) {
                        finish()
                        return
                    }
                    handler.postDelayed(this, 1000)
                }
            }
        }
        handler.post(timerRunnable!!)
    }

    private fun getTimeRemaining(): String {
        val endMs = prefs.getLong(FocusAccessibilityService.KEY_SESSION_END, 0L)
        if (endMs == 0L) return "Active"
        val diffMs = endMs - System.currentTimeMillis()
        if (diffMs <= 0) return "Done"
        val mins = (diffMs / 60000).toInt()
        val secs = ((diffMs % 60000) / 1000).toInt()
        return String.format("%02d:%02d", mins, secs)
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    private fun goHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    private fun getAppDisplayName(packageName: String): String {
        return try {
            val pm = packageManager
            val info = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            packageName.substringAfterLast('.')
        }
    }

    private fun spaceView(heightDp: Int): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (heightDp * resources.displayMetrics.density).toInt()
            )
        }
    }

    private fun dividerView(): View {
        return View(this).apply {
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (1 * resources.displayMetrics.density).toInt()
            )
        }
    }

    private fun buildButtonBackground(): GradientDrawable {
        return GradientDrawable(
            GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(Color.parseColor("#7B61FF"), Color.parseColor("#00D4FF"))
        ).apply {
            cornerRadius = 40f * resources.displayMetrics.density
        }
    }
}
