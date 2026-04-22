package com.ruilynx.banana_toolbox

import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs

// For backward compatibility with HapticFeedbackConstants
private val HapticFeedbackConstants_VIRTUAL_KEY: Int =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) HapticFeedbackConstants.VIRTUAL_KEY
    else 1 // fallback

/**
 * Manager for floating "dynamic island" style mini progress window
 * with smooth enter/exit animations
 */
object FloatingWindowManager {
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var isShowing = false
    private var isAnimating = false

    // Animation constants
    private const val ANIMATION_DURATION = 400L
    private const val EXIT_ANIMATION_DURATION = 300L
    private const val INITIAL_SCALE = 0.6f
    private const val OVERSHOOT_SCALE = 1.05f
    private const val AUTO_HIDE_DELAY_MS = 3000L
    private const val PROGRESS_ESTIMATE_MIN_MS = 5000L // Minimum estimated time
    private const val PROGRESS_ESTIMATE_MAX_MS = 120000L // Maximum estimated time

    // View elements
    private var containerView: FrameLayout? = null
    private var queueText: TextView? = null
    private var progressText: TextView? = null
    private var progressBar: ProgressBar? = null
    private var statusIcon: ImageView? = null
    private var contentContainer: FrameLayout? = null
    private var expandedQueueContainer: LinearLayout? = null
    private var miniControlsContainer: LinearLayout? = null
    private var pauseButton: ImageView? = null
    private var cancelButton: ImageView? = null

    // State tracking
    private var currentProgress = 0
    private var queueCount = 0
    private var currentStatus = "idle"
    private var estimatedSeconds: Int? = null
    private var startTime: Long = 0
    private var isExpanded = false
    private var animator: ValueAnimator? = null
    private var exitAnimator: ValueAnimator? = null
    private val handler = Handler(Looper.getMainLooper())
    private var autoHideRunnable: Runnable? = null
    private var progressUpdateRunnable: Runnable? = null
    private var onPauseCallback: (() -> Unit)? = null
    private var onCancelCallback: (() -> Unit)? = null
    private var windowParams: WindowManager.LayoutParams? = null

    /**
     * Show the floating window with animation
     */
    fun show(
        context: Context,
        queue: Int,
        progress: Int,
        status: String,
        estimatedSecs: Int? = null,
        onPause: (() -> Unit)? = null,
        onCancel: (() -> Unit)? = null
    ) {
        currentProgress = progress
        queueCount = queue
        currentStatus = status
        estimatedSeconds = estimatedSecs
        onPauseCallback = onPause
        onCancelCallback = onCancel

        if (startTime == 0L && status == "running") {
            startTime = System.currentTimeMillis()
        }

        if (isShowing && floatingView != null) {
            // Already showing, just update content with smooth animation
            updateContent(animate = true)
            return
        }

        if (isAnimating || context !is Activity) return

        isAnimating = true

        try {
            createFloatingWindow(context)
            animateEntry()
            startProgressUpdates()
        } catch (e: Exception) {
            isAnimating = false
            cleanup()
        }
    }

    /**
     * Update the floating window content
     */
    fun update(
        context: Context,
        queue: Int,
        progress: Int,
        status: String,
        estimatedSecs: Int? = null
    ) {
        currentProgress = progress
        queueCount = queue
        currentStatus = status
        estimatedSeconds = estimatedSecs

        if (isShowing && floatingView != null) {
            updateContent(animate = true)
        } else if (!isShowing && !isAnimating) {
            show(context, queue, progress, status, estimatedSecs, onPauseCallback, onCancelCallback)
        }

        // Auto hide on success/error after delay
        if (status == "success" || status == "error") {
            stopProgressUpdates()
            scheduleAutoHide()
        } else {
            cancelAutoHide()
            startProgressUpdates()
        }
    }

    /**
     * Hide the floating window with smooth animation
     */
    fun hide() {
        if (!isShowing || floatingView == null || isAnimating) {
            cleanup()
            return
        }

        cancelAutoHide()
        stopProgressUpdates()
        animateExit()
    }

    private fun createFloatingWindow(context: Activity) {
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        floatingView = createView(context)

        val params = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL

            // Position below status bar (roughly aligned with notch/cutout area)
            y = getStatusBarHeight(context) + 8

            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL

            format = PixelFormat.TRANSLUCENT
        }
        windowParams = params

        try {
            windowManager?.addView(floatingView, params)
            isShowing = true

            // Initial state for animation
            floatingView?.apply {
                alpha = 0f
                scaleX = INITIAL_SCALE
                scaleY = INITIAL_SCALE
                translationY = -50f
            }
        } catch (e: Exception) {
            cleanup()
            throw e
        }
    }

    private fun createView(context: Context): View {
        val rootContainer = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            )

            // Main floating island container
            val container = FrameLayout(context).apply {
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT
                )

                // Background with rounded corners and blur-like effect
                background = ContextCompat.getDrawable(context, R.drawable.floating_island_bg)
                    ?: createDefaultBackground(context)

                elevation = 16f

                // Touch handling for tap to expand and drag
                setOnTouchListener(object : View.OnTouchListener {
                    private var initialX = 0f
                    private var initialY = 0f
                    private var initialTouchX = 0f
                    private var initialTouchY = 0f
                    private var isDragging = false
                    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop

                    override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                        event ?: return false
                        when (event.action) {
                            MotionEvent.ACTION_DOWN -> {
                                initialX = windowParams?.x?.toFloat() ?: 0f
                                initialY = windowParams?.y?.toFloat() ?: 0f
                                initialTouchX = event.rawX
                                initialTouchY = event.rawY
                                isDragging = false
                                return true
                            }
                            MotionEvent.ACTION_MOVE -> {
                                val dx = event.rawX - initialTouchX
                                val dy = event.rawY - initialTouchY
                                if (!isDragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                                    isDragging = true
                                }
                                if (isDragging) {
                                    windowParams?.x = (initialX + dx).toInt()
                                    windowParams?.y = (initialY + dy).toInt()
                                    windowManager?.updateViewLayout(this@apply, windowParams)
                                }
                                return true
                            }
                            MotionEvent.ACTION_UP -> {
                                if (!isDragging) {
                                    // It was a tap - toggle expanded view
                                    toggleExpandedView()
                                } else {
                                    // Snap to nearest edge if dragged
                                    snapToEdge()
                                }
                                return true
                            }
                        }
                        return false
                    }
                })

                // Inner content container
                val content = FrameLayout(context).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        setPadding(20, 12, 20, 12)
                    }

                    // Status icon (left side)
                    statusIcon = ImageView(context).apply {
                        layoutParams = FrameLayout.LayoutParams(24, 24).apply {
                            gravity = Gravity.CENTER_VERTICAL or Gravity.START
                        }
                        visibility = View.GONE
                    }
                    addView(statusIcon)

                    // Queue count (left side) with badge styling
                    queueText = TextView(context).apply {
                        layoutParams = FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.WRAP_CONTENT,
                            FrameLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            gravity = Gravity.CENTER_VERTICAL or Gravity.START
                            marginStart = 0
                        }
                        textSize = 12f
                        setTextColor(0xFFFFFFFF.toInt())
                        alpha = 0.9f
                    }
                    addView(queueText)

                    // Progress bar (center)
                    progressBar = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
                        layoutParams = FrameLayout.LayoutParams(60, 6).apply {
                            gravity = Gravity.CENTER
                            marginStart = 60
                            marginEnd = 60
                        }
                        isIndeterminate = true
                        visibility = View.GONE
                        progressDrawable = ContextCompat.getDrawable(context, R.drawable.floating_progress_bar)
                    }
                    addView(progressBar)

                    // Progress text (right side)
                    progressText = TextView(context).apply {
                        layoutParams = FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.WRAP_CONTENT,
                            FrameLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            gravity = Gravity.CENTER_VERTICAL or Gravity.END
                        }
                        textSize = 12f
                        setTextColor(0xFFFFFFFF.toInt())
                        alpha = 0.9f
                    }
                    addView(progressText)

                    contentContainer = this
                }
                addView(content)

                // Mini controls (pause/cancel) - hidden by default
                miniControlsContainer = LinearLayout(context).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.CENTER_VERTICAL or Gravity.END
                        marginEnd = 8
                    }
                    orientation = LinearLayout.HORIZONTAL
                    visibility = View.GONE

                    // Pause button
                    pauseButton = ImageView(context).apply {
                        layoutParams = LinearLayout.LayoutParams(28, 28).apply {
                            marginEnd = 8
                        }
                        setImageResource(android.R.drawable.ic_media_pause)
                        setColorFilter(0xFFFFFFFF.toInt())
                        alpha = 0.8f
                        setOnClickListener {
                            onPauseCallback?.invoke()
                            performHapticFeedback(HapticFeedbackConstants_VIRTUAL_KEY)
                        }
                    }
                    addView(pauseButton)

                    // Cancel button
                    cancelButton = ImageView(context).apply {
                        layoutParams = LinearLayout.LayoutParams(28, 28)
                        setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
                        setColorFilter(0xFFE53935.toInt()) // Red
                        alpha = 0.8f
                        setOnClickListener {
                            onCancelCallback?.invoke()
                            performHapticFeedback(HapticFeedbackConstants_VIRTUAL_KEY)
                        }
                    }
                    addView(cancelButton)
                }
                addView(miniControlsContainer)

                containerView = this
            }
            addView(container)

            // Expanded queue preview - shown below main island when tapped
            expandedQueueContainer = LinearLayout(context).apply {
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    topMargin = 60 // Below main island
                }
                orientation = LinearLayout.VERTICAL
                visibility = View.GONE

                background = ContextCompat.getDrawable(context, R.drawable.floating_island_bg)
                    ?: createDefaultBackground(context)
                elevation = 12f
                setPadding(16, 12, 16, 12)
            }
            addView(expandedQueueContainer)
        }

        // Set initial content
        updateContent(animate = false)

        return rootContainer
    }

    private fun createDefaultBackground(context: Context): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = 24f
            setColor(0xE6000000.toInt()) // Semi-transparent black
        }
    }

    private fun updateContent(animate: Boolean) {
        val context = containerView?.context ?: return

        // Update queue text
        queueText?.text = if (queueCount > 0) "$queueCount" else ""
        queueText?.visibility = if (queueCount > 0) View.VISIBLE else View.GONE

        // Update progress text and icon based on status
        when (currentStatus) {
            "running" -> {
                progressText?.text = if (currentProgress > 0) "$currentProgress%" else "..."
                progressBar?.visibility = View.VISIBLE
                statusIcon?.visibility = View.GONE
                progressBar?.isIndeterminate = currentProgress <= 0
                if (currentProgress > 0) {
                    progressBar?.isIndeterminate = false
                    progressBar?.progress = currentProgress
                }
            }
            "success" -> {
                progressText?.text = ""
                progressBar?.visibility = View.GONE
                statusIcon?.apply {
                    visibility = View.VISIBLE
                    setImageResource(R.drawable.ic_check_circle)
                    setColorFilter(0xFF4CAF50.toInt()) // Green
                }
                // Pulse animation for success
                if (animate) pulseAnimation()
            }
            "error" -> {
                progressText?.text = ""
                progressBar?.visibility = View.GONE
                statusIcon?.apply {
                    visibility = View.VISIBLE
                    setImageResource(R.drawable.ic_error)
                    setColorFilter(0xFFE53935.toInt()) // Red
                }
                // Shake animation for error
                if (animate) shakeAnimation()
            }
            else -> {
                progressText?.text = "..."
                progressBar?.visibility = View.VISIBLE
                progressBar?.isIndeterminate = true
                statusIcon?.visibility = View.GONE
            }
        }
    }

    private fun animateEntry() {
        val view = floatingView ?: return

        // Cancel any existing animation
        animator?.cancel()

        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = ANIMATION_DURATION
            interpolator = OvershootInterpolator(1.2f)

            addUpdateListener { animation ->
                val fraction = animation.animatedValue as Float

                // Scale with overshoot
                val scale = when {
                    fraction < 0.8f -> INITIAL_SCALE + (OVERSHOOT_SCALE - INITIAL_SCALE) * (fraction / 0.8f)
                    else -> OVERSHOOT_SCALE - (OVERSHOOT_SCALE - 1f) * ((fraction - 0.8f) / 0.2f)
                }

                view.scaleX = scale
                view.scaleY = scale
                view.alpha = fraction
                view.translationY = -50f * (1f - fraction)
            }

            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    isAnimating = false
                    view.scaleX = 1f
                    view.scaleY = 1f
                    view.translationY = 0f
                }

                override fun onAnimationCancel(animation: android.animation.Animator) {
                    isAnimating = false
                }
            })

            start()
        }
    }

    private fun animateExit() {
        val view = floatingView ?: return
        isAnimating = true

        // Cancel any existing animation
        animator?.cancel()
        exitAnimator?.cancel()

        exitAnimator = ValueAnimator.ofFloat(1f, 0f).apply {
            duration = EXIT_ANIMATION_DURATION
            interpolator = DecelerateInterpolator()

            addUpdateListener { animation ->
                val fraction = animation.animatedValue as Float
                val scale = 0.8f + 0.2f * fraction

                view.scaleX = scale
                view.scaleY = scale
                view.alpha = fraction
                view.translationY = -30f * (1f - fraction)
            }

            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    cleanup()
                }

                override fun onAnimationCancel(animation: android.animation.Animator) {
                    cleanup()
                }
            })

            start()
        }
    }

    private fun pulseAnimation() {
        containerView?.animate()
            ?.scaleX(1.1f)
            ?.scaleY(1.1f)
            ?.setDuration(150)
            ?.withEndAction {
                containerView?.animate()
                    ?.scaleX(1f)
                    ?.scaleY(1f)
                    ?.setDuration(150)
                    ?.start()
            }
            ?.start()
    }

    private fun shakeAnimation() {
        val view = containerView ?: return
        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 400
            addUpdateListener { animation ->
                val fraction = animation.animatedValue as Float
                val offset =
                    (kotlin.math.sin(fraction * kotlin.math.PI * 4) * 8f * (1f - fraction))
                        .toFloat()
                view.translationX = offset
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    view.translationX = 0f
                }
            })
            start()
        }
    }

    private fun scheduleAutoHide() {
        cancelAutoHide()
        autoHideRunnable = Runnable {
            hide()
        }.also { handler.postDelayed(it, AUTO_HIDE_DELAY_MS) }
    }

    private fun cancelAutoHide() {
        autoHideRunnable?.let { handler.removeCallbacks(it) }
        autoHideRunnable = null
    }

    private fun startProgressUpdates() {
        stopProgressUpdates()
        if (currentStatus != "running") return

        val runnable = object : Runnable {
            override fun run() {
                if (currentStatus != "running") return
                // Calculate estimated progress based on elapsed time if no real progress
                if (currentProgress <= 0 && startTime > 0) {
                    val elapsed = System.currentTimeMillis() - startTime
                    // Estimate: assume 30 seconds total, calculate fake progress up to 80%
                    val estimatedProgress = ((elapsed / 300.0).toInt().coerceIn(0, 80))
                    if (estimatedProgress > 0) {
                        updateProgressEstimate(estimatedProgress)
                    }
                }
                // Update estimated time remaining
                updateEstimatedTime()
                progressUpdateRunnable?.let { handler.postDelayed(it, 500) }
            }
        }
        progressUpdateRunnable = runnable
        handler.postDelayed(runnable, 500)
    }

    private fun stopProgressUpdates() {
        progressUpdateRunnable?.let { handler.removeCallbacks(it) }
        progressUpdateRunnable = null
        startTime = 0
    }

    private fun updateProgressEstimate(estimatedProgress: Int) {
        // Only update UI, don't override real progress
        if (currentProgress <= 0) {
            progressText?.text = "..."
            progressBar?.isIndeterminate = true
        }
    }

    private fun updateEstimatedTime() {
        estimatedSeconds?.let { seconds ->
            val remaining = (seconds * (100 - currentProgress) / 100.0).toInt()
            if (remaining > 0 && currentStatus == "running") {
                progressText?.text = "${currentProgress}% (~${remaining}s)"
            }
        }
    }

    private fun toggleExpandedView() {
        isExpanded = !isExpanded
        expandedQueueContainer?.visibility = if (isExpanded) View.VISIBLE else View.GONE
        miniControlsContainer?.visibility = if (isExpanded && currentStatus == "running") View.VISIBLE else View.GONE

        if (isExpanded) {
            updateExpandedQueueView()
        }

        // Animate expansion
        expandedQueueContainer?.animate()
            ?.alpha(if (isExpanded) 1f else 0f)
            ?.translationY(if (isExpanded) 0f else -20f)
            ?.setDuration(200)
            ?.start()
    }

    private fun updateExpandedQueueView() {
        val container = expandedQueueContainer ?: return
        container.removeAllViews()

        // Add header
        val header = TextView(container.context).apply {
            text = "队列 (${queueCount})"
            textSize = 12f
            setTextColor(0xFFFFFFFF.toInt())
            alpha = 0.7f
            setPadding(0, 0, 0, 8)
        }
        container.addView(header)

        // Add queue items (placeholder for actual task names)
        for (i in 0 until minOf(queueCount, 5)) {
            val item = TextView(container.context).apply {
                text = "任务 ${i + 1}${if (i == 0) " - 进行中" else ""}"
                textSize = 11f
                setTextColor(0xFFFFFFFF.toInt())
                alpha = if (i == 0) 1f else 0.5f
                setPadding(4, 2, 4, 2)
            }
            container.addView(item)
        }

        if (queueCount > 5) {
            val more = TextView(container.context).apply {
                text = "... 还有 ${queueCount - 5} 个任务"
                textSize = 10f
                setTextColor(0x80FFFFFF.toInt())
                setPadding(4, 2, 4, 2)
            }
            container.addView(more)
        }

        // Add estimated time
        estimatedSeconds?.let { est ->
            val timeText = TextView(container.context).apply {
                val remaining = (est * (100 - currentProgress) / 100.0).toInt()
                text = "预计剩余: ${remaining}秒"
                textSize = 11f
                setTextColor(0xFF4CAF50.toInt())
                setPadding(0, 8, 0, 0)
            }
            container.addView(timeText)
        }
    }

    private fun snapToEdge() {
        val params = windowParams ?: return
        val metrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(metrics)

        val centerX = metrics.widthPixels / 2
        val currentX = params.x
        val distanceToCenter = abs(currentX)

        // Determine which edge is closer
        val targetX = when {
            currentX < -metrics.widthPixels / 4 -> -centerX + 50 // Left edge
            currentX > metrics.widthPixels / 4 -> centerX - 50 // Right edge
            else -> 0 // Center (default)
        }

        // Animate to target position
        ValueAnimator.ofInt(currentX, targetX).apply {
            duration = 300
            interpolator = DecelerateInterpolator()
            addUpdateListener { animation ->
                params.x = animation.animatedValue as Int
                try {
                    windowManager?.updateViewLayout(floatingView, params)
                } catch (_: Exception) {}
            }
            start()
        }
    }

    private fun cleanup() {
        try {
            if (floatingView != null && windowManager != null) {
                windowManager?.removeView(floatingView)
            }
        } catch (_: Exception) {
            // Ignore
        }
        floatingView = null
        containerView = null
        queueText = null
        progressText = null
        progressBar = null
        statusIcon = null
        contentContainer = null
        expandedQueueContainer = null
        miniControlsContainer = null
        pauseButton = null
        cancelButton = null
        windowParams = null
        isShowing = false
        isAnimating = false
        animator?.cancel()
        animator = null
        exitAnimator?.cancel()
        exitAnimator = null
        cancelAutoHide()
    }

    private fun getStatusBarHeight(context: Context): Int {
        val resourceId = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) {
            context.resources.getDimensionPixelSize(resourceId)
        } else {
            64 // Default fallback
        }
    }

    /**
     * Check if floating window can be shown (needs SYSTEM_ALERT_WINDOW permission)
     */
    fun canShow(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.provider.Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    /**
     * Request permission to draw over other apps
     */
    fun requestPermission(context: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:${context.packageName}")
            )
            context.startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
        }
    }

    private const val REQUEST_OVERLAY_PERMISSION = 200201
}