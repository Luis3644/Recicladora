package com.example.flutter_application_1

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
	private val channelName = "recicladora_update_installer"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"openInstaller" -> {
						try {
							val apkPath = call.argument<String>("apkPath")
							if (apkPath.isNullOrBlank()) {
								result.error("invalid_path", "apkPath vacío", null)
								return@setMethodCallHandler
							}

							val apkFile = File(apkPath)
							if (!apkFile.exists()) {
								result.error("file_not_found", "No existe el APK", null)
								return@setMethodCallHandler
							}

							val uri: Uri = FileProvider.getUriForFile(
								this,
								"${applicationContext.packageName}.fileprovider",
								apkFile
							)

							val intent = Intent(Intent.ACTION_VIEW).apply {
								setDataAndType(uri, "application/vnd.android.package-archive")
								addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
								addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							}

							startActivity(intent)
							result.success(true)
						} catch (e: Exception) {
							result.error("open_failed", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}
}
