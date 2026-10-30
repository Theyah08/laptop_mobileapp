package com.example.prosforagiftshop

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"prosfora_gift_shop/storage"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getAppFilesDirectory" -> result.success(applicationContext.filesDir.absolutePath)
				else -> result.notImplemented()
			}
		}
	}
}
