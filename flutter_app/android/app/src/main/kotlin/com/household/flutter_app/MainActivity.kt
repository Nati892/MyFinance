package com.household.flutter_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "household/package_info")
            .setMethodCallHandler { call, result ->
                if (call.method == "getInstallTime") {
                    try {
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        result.success(pInfo.firstInstallTime)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
