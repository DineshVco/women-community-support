package com.example.women_community_support

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity): needed by local_auth for
// fingerprint / face unlock.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Hide Looma in recent apps" (App lock setting).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "looma/privacy")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    setSecure(call.argument<Boolean>("secure") == true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun setSecure(secure: Boolean) {
        // FLAG_SECURE: blank preview in recent apps. It also blocks
        // screenshots and screen recording while it is on.
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(!secure)
        }
    }
}
