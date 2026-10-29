package com.spookysrv.hktransports

import android.os.Build
import android.view.RoundedCorner
import android.view.WindowInsets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val displayChannel = "com.spookysrv.hktransports/display"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, displayChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCornerRadius" -> result.success(cornerRadius())
                    else -> result.notImplemented()
                }
            }
    }

    private fun cornerRadius(): Double {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return 0.0
        val insets = window?.decorView?.rootWindowInsets ?: return 0.0
        val positions = intArrayOf(
            RoundedCorner.POSITION_TOP_LEFT,
            RoundedCorner.POSITION_TOP_RIGHT,
            RoundedCorner.POSITION_BOTTOM_LEFT,
            RoundedCorner.POSITION_BOTTOM_RIGHT,
        )
        var radius = 0.0
        for (position in positions) {
            val corner = insets.getRoundedCorner(position) ?: continue
            radius = maxOf(radius, corner.radius.toDouble())
        }
        return radius
    }
}
