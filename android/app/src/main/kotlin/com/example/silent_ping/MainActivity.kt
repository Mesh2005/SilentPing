package com.example.silent_ping

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.app.NotificationChannel
import android.app.NotificationManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "silent_ping/haptics")
            .setMethodCallHandler { call, result ->
                if (call.method == "prepareNotifications") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        val patterns = mapOf(
                            "ambient" to Pair("Thinking of you", longArrayOf(0, 160)),
                            "arrival" to Pair("Arrived safely", longArrayOf(0, 140, 180, 140)),
                            "attention" to Pair("Need a moment", longArrayOf(0, 350))
                        )
                        for ((kind, details) in patterns) {
                            val channel = NotificationChannel("silentping_${kind}_v1", details.first, NotificationManager.IMPORTANCE_HIGH)
                            channel.description = "Quiet pings from your approved connections"
                            channel.setSound(null, null)
                            channel.enableVibration(true)
                            channel.vibrationPattern = details.second
                            manager.createNotificationChannel(channel)
                        }
                    }
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "preview") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val timings = when (call.arguments as? String) {
                    "ambient" -> longArrayOf(0, 160)
                    "arrival" -> longArrayOf(0, 140, 180, 140)
                    "attention" -> longArrayOf(0, 350)
                    else -> {
                        result.error("INVALID_SIGNAL", "Unknown signal", null)
                        return@setMethodCallHandler
                    }
                }
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (vibrator == null || !vibrator.hasVibrator()) {
                    result.error("UNAVAILABLE", "No vibration motor available", null)
                    return@setMethodCallHandler
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(timings, -1)
                    }
                    result.success(null)
                } catch (error: SecurityException) {
                    result.error("PERMISSION_DENIED", "Vibration permission unavailable", null)
                }
            }
    }
}
