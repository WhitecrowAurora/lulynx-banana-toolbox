package com.ruilynx.banana_toolbox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class KeepAliveForegroundService : Service() {
    companion object {
        const val ACTION_START = "com.ruilynx.banana_toolbox.action.START_KEEP_ALIVE"
        const val ACTION_STOP = "com.ruilynx.banana_toolbox.action.STOP_KEEP_ALIVE"
        const val ACTION_UPDATE = "com.ruilynx.banana_toolbox.action.UPDATE_PROGRESS"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_QUEUE_COUNT = "queue_count"
        const val EXTRA_CURRENT_PROGRESS = "current_progress"
        const val EXTRA_STATUS = "status" // "running", "success", "error"
        const val EXTRA_MESSAGE = "message"

        private const val CHANNEL_ID = "nano_banana_keep_alive"
        private const val CHANNEL_NAME = "生成任务后台驻留"
        private const val NOTIFICATION_ID = 200101

        // Status values
        const val STATUS_RUNNING = "running"
        const val STATUS_SUCCESS = "success"
        const val STATUS_ERROR = "error"
        const val STATUS_IDLE = "idle"

        private var currentStatus: String = STATUS_IDLE
        private var currentProgress: Int = 0
        private var queueCount: Int = 0
        private var currentMessage: String = ""
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundService()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                updateFromIntent(intent)
                // Update notification without restarting foreground
                val manager = getSystemService(NotificationManager::class.java)
                manager?.notify(NOTIFICATION_ID, buildNotification())
                return START_NOT_STICKY
            }
            else -> {
                // Start or update service
                updateFromIntent(intent)
                if (currentStatus == STATUS_IDLE || currentStatus == STATUS_RUNNING) {
                    startForeground(NOTIFICATION_ID, buildNotification())
                } else {
                    // For success/error, update notification and stop foreground
                    val manager = getSystemService(NotificationManager::class.java)
                    manager?.notify(NOTIFICATION_ID, buildNotification())
                    stopForeground(STOP_FOREGROUND_DETACH)
                    // Delay stopSelf() to let user see the final state
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        stopForegroundService()
                    }, 3000)
                }
            }
        }
        return START_NOT_STICKY
    }

    private fun updateFromIntent(intent: Intent?) {
        intent?.getStringExtra(EXTRA_STATUS)?.let { currentStatus = it }
        intent?.getIntExtra(EXTRA_CURRENT_PROGRESS, currentProgress)?.let { currentProgress = it }
        intent?.getIntExtra(EXTRA_QUEUE_COUNT, queueCount)?.let { queueCount = it }
        intent?.getStringExtra(EXTRA_MESSAGE)?.let { currentMessage = it }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForegroundService()
        super.onDestroy()
    }

    private fun stopForegroundService() {
        FloatingWindowManager.hide()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP

        val pendingIntentFlags =
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent =
            PendingIntent.getActivity(this, 0, launchIntent, pendingIntentFlags)

        // Build content text based on status
        val contentText = when (currentStatus) {
            STATUS_RUNNING -> {
                val progressText = if (currentProgress > 0) "$currentProgress%" else "处理中"
                if (queueCount > 0) "队列: $queueCount | 进度: $progressText" else "生成中: $progressText"
            }
            STATUS_SUCCESS -> "✓ 生成完成"
            STATUS_ERROR -> "✗ 生成失败"
            else -> currentMessage.ifEmpty { "正在处理生成任务" }
        }

        val contentTitle = when (currentStatus) {
            STATUS_RUNNING -> "🎨 Nano Banana 生成中"
            STATUS_SUCCESS -> "✨ 完成"
            STATUS_ERROR -> "❌ 出错了"
            else -> "Nano Banana"
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)

        when (currentStatus) {
            STATUS_RUNNING -> {
                builder.setOngoing(true)
                builder.setProgress(100, currentProgress, currentProgress <= 0)
                builder.setPriority(NotificationCompat.PRIORITY_LOW)
            }
            STATUS_SUCCESS -> {
                builder.setOngoing(false)
                builder.setProgress(0, 0, false)
                builder.setPriority(NotificationCompat.PRIORITY_DEFAULT)
            }
            STATUS_ERROR -> {
                builder.setOngoing(false)
                builder.setProgress(0, 0, false)
                builder.setPriority(NotificationCompat.PRIORITY_DEFAULT)
            }
            else -> {
                builder.setOngoing(true)
                builder.setPriority(NotificationCompat.PRIORITY_LOW)
            }
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "保持生成任务在后台稳定运行"
            setShowBadge(false)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
