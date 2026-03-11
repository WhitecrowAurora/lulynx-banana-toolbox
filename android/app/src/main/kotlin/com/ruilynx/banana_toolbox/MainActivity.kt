package com.ruilynx.banana_toolbox

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val MEDIA_CHANNEL = "com.nanobanana/media_scanner"
    private val FOREGROUND_CHANNEL = "com.nanobanana/foreground_service"
    private val LOG_FILE_CHANNEL = "com.nanobanana/log_file"
    private val IMAGE_CHOOSER_CHANNEL = "com.nanobanana/image_chooser"
    private val APP_UPDATE_CHANNEL = "com.nanobanana/app_update"
    private val IMAGE_CHOOSER_REQUEST_CODE = 20031
    private var pendingImageChooserResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "NanoBanana_${System.currentTimeMillis()}.png"
                    val mimeType = call.argument<String>("mimeType") ?: "image/png"

                    if (bytes != null) {
                        try {
                            val savedPath = saveImageToGallery(bytes, fileName, mimeType)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_DATA", "Bytes is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startKeepAliveService" -> {
                        val title = call.argument<String>("title")
                            ?: "Nano Banana 正在后台运行"
                        val text = call.argument<String>("text")
                            ?: "正在处理生成任务，请勿关闭应用"
                        startKeepAliveService(title, text)
                        result.success(true)
                    }

                    "stopKeepAliveService" -> {
                        stopKeepAliveService()
                        result.success(true)
                    }

                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }

                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("FOREGROUND_SERVICE_ERROR", e.message, null)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_FILE_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "shareLogText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val subject = call.argument<String>("subject")
                        if (text.isBlank()) {
                            result.error("EMPTY_LOG", "Log text is empty", null)
                        } else {
                            shareText(text, subject)
                            result.success(true)
                        }
                    }

                    "saveLogToDownloads" -> {
                        val text = call.argument<String>("text") ?: ""
                        val fileName = call.argument<String>("fileName")
                            ?: "nano_banana_log_${System.currentTimeMillis()}.log"
                        if (text.isBlank()) {
                            result.error("EMPTY_LOG", "Log text is empty", null)
                        } else {
                            val savedPath = saveLogToDownloads(text, fileName)
                            result.success(savedPath)
                        }
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("LOG_OP_ERROR", e.message, null)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IMAGE_CHOOSER_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "pickImageWithChooser" -> {
                            val title = call.argument<String>("title")
                            launchImageChooser(result, title)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("IMAGE_CHOOSER_ERROR", e.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installApk" -> {
                            val apkPath = call.argument<String>("apkPath")
                            if (apkPath.isNullOrBlank()) {
                                result.error("INVALID_APK_PATH", "APK path is empty", null)
                            } else {
                                val installResult = installDownloadedApk(apkPath)
                                result.success(installResult)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("APP_UPDATE_ERROR", e.message, null)
                }
            }
    }

    private fun startKeepAliveService(title: String, text: String) {
        val intent = Intent(this, KeepAliveForegroundService::class.java).apply {
            action = KeepAliveForegroundService.ACTION_START
            putExtra(KeepAliveForegroundService.EXTRA_TITLE, title)
            putExtra(KeepAliveForegroundService.EXTRA_TEXT, text)
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun stopKeepAliveService() {
        val intent = Intent(this, KeepAliveForegroundService::class.java).apply {
            action = KeepAliveForegroundService.ACTION_STOP
        }
        startService(intent)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val powerManager = getSystemService(PowerManager::class.java)
        return powerManager?.isIgnoringBatteryOptimizations(packageName) == true
    }

    private fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val requestIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }

        try {
            startActivity(requestIntent)
        } catch (_: Exception) {
            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(fallbackIntent)
        }
    }

    private fun shareText(text: String, subject: String?) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (!subject.isNullOrBlank()) {
                putExtra(Intent.EXTRA_SUBJECT, subject)
            }
        }
        startActivity(Intent.createChooser(intent, "分享日志"))
    }

    private fun saveLogToDownloads(text: String, fileName: String): String {
        val bytes = text.toByteArray(Charsets.UTF_8)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/NanoBanana"
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create download entry")

            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
            } ?: throw Exception("Failed to open output stream")

            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            "Download/NanoBanana/$fileName"
        } else {
            val downloadsDir =
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val nanoBananaDir = File(downloadsDir, "NanoBanana")
            if (!nanoBananaDir.exists()) {
                nanoBananaDir.mkdirs()
            }

            val file = File(nanoBananaDir, fileName)
            FileOutputStream(file).use { it.write(bytes) }
            android.media.MediaScannerConnection.scanFile(
                this,
                arrayOf(file.absolutePath),
                arrayOf("text/plain"),
                null
            )
            file.absolutePath
        }
    }

    private fun saveImageToGallery(bytes: ByteArray, fileName: String, mimeType: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ 使用 MediaStore API
            saveWithMediaStore(bytes, fileName, mimeType)
        } else {
            // Android 9 及以下使用传统方式
            saveWithLegacy(bytes, fileName, mimeType)
        }
    }

    private fun saveWithMediaStore(bytes: ByteArray, fileName: String, mimeType: String): String {
        val contentValues = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/NanoBanana")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }

        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            ?: throw Exception("Failed to create media store entry")

        resolver.openOutputStream(uri)?.use { outputStream ->
            outputStream.write(bytes)
        } ?: throw Exception("Failed to open output stream")

        contentValues.clear()
        contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
        resolver.update(uri, contentValues, null, null)

        return "Pictures/NanoBanana/$fileName"
    }

    private fun saveWithLegacy(bytes: ByteArray, fileName: String, mimeType: String): String {
        val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val nanoBananaDir = File(picturesDir, "NanoBanana")

        if (!nanoBananaDir.exists()) {
            nanoBananaDir.mkdirs()
        }

        val file = File(nanoBananaDir, fileName)
        FileOutputStream(file).use { it.write(bytes) }

        // 触发媒体扫描
        android.media.MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf(mimeType),
            null
        )

        return file.absolutePath
    }

    private fun launchImageChooser(result: MethodChannel.Result, title: String?) {
        if (pendingImageChooserResult != null) {
            result.error("PICKER_BUSY", "Another image picker request is in progress", null)
            return
        }
        pendingImageChooserResult = result

        val getContentIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
        }
        val chooserIntent = Intent.createChooser(
            getContentIntent,
            title ?: "选择应用上传图片"
        )
        try {
            startActivityForResult(chooserIntent, IMAGE_CHOOSER_REQUEST_CODE)
        } catch (e: Exception) {
            pendingImageChooserResult = null
            result.error("IMAGE_CHOOSER_LAUNCH_ERROR", e.message, null)
        }
    }

    private fun installDownloadedApk(apkPath: String): String {
        val apkFile = File(apkPath)
        if (!apkFile.exists() || !apkFile.isFile) {
            throw Exception("APK file not found")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(settingsIntent)
            return "permission_required"
        }

        val authority = "$packageName.fileprovider"
        val contentUri = FileProvider.getUriForFile(this, authority, apkFile)
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(contentUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        if (installIntent.resolveActivity(packageManager) == null) {
            throw Exception("No installer available")
        }

        startActivity(installIntent)
        return "install_started"
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) {
                    cursor.getString(idx)
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != IMAGE_CHOOSER_REQUEST_CODE) return

        val result = pendingImageChooserResult ?: return
        pendingImageChooserResult = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null || bytes.isEmpty()) {
                result.error("EMPTY_IMAGE", "Picked image is empty", null)
                return
            }
            val payload = hashMapOf<String, Any?>(
                "bytes" to bytes,
                "uri" to uri.toString(),
                "name" to queryDisplayName(uri)
            )
            result.success(payload)
        } catch (e: Exception) {
            result.error("READ_IMAGE_ERROR", e.message, null)
        }
    }
}
