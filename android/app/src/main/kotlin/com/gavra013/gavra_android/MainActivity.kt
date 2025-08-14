package com.gavra013.gavra_android

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "gavra_android/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        try {
                            installApk(apkPath)
                            result.success("APK installation started")
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", "Failed to install APK: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "APK path is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun installApk(apkPath: String) {
        val file = File(apkPath)
        if (!file.exists()) {
            throw Exception("APK file does not exist: $apkPath")
        }

        val intent = Intent(Intent.ACTION_VIEW)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7.0+ zahteva FileProvider
            FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
        } else {
            // Starije verzije Android-a
            Uri.fromFile(file)
        }

        intent.setDataAndType(uri, "application/vnd.android.package-archive")
        startActivity(intent)
    }
}
