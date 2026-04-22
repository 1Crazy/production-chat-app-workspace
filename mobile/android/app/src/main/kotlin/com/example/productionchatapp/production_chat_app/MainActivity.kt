package com.example.productionchatapp.production_chat_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val badgeChannelName = "production_chat_app/badge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, badgeChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "setBadgeCount") {
                    // Android 桌面角标由 launcher/通知系统决定，当前仅保持跨平台接口稳定。
                    result.success(null)
                    return@setMethodCallHandler
                }

                result.notImplemented()
            }
    }
}
