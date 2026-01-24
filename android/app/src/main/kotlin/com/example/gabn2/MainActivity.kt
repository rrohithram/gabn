package com.example.gabn2

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.gabn2/gestures"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVolumeButtonListener" -> {
                    // Volume button handling is done via onKeyDown
                    result.success(true)
                }
                "stopVolumeButtonListener" -> {
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Handle volume button presses
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            // Send event to Flutter
            try {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL).invokeMethod("volumeButtonPressed", null)
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error sending volume button event: ${e.message}")
            }
            // Return false to allow normal volume control, but also notify Flutter
            return false
        }
        return super.onKeyDown(keyCode, event)
    }
}
