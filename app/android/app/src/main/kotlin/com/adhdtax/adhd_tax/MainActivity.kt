package com.adhdtax.adhd_tax

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands the app two kinds of outside requests over the "unstuck/android"
 * channel: text shared from another app ("Share → Gumption"), and taps on the
 * home-screen widget (open a route). Also lets the app refresh the widget.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** The request that launched the app, until Dart asks for it. */
    private var pending: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Reopened from Recents, the old share intent comes back: ignore it.
        if (savedInstanceState == null &&
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0
        ) {
            pending = requestFrom(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val request = requestFrom(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("request", request) else pending = request
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeLaunchRequest" -> {
                        result.success(pending)
                        pending = null
                    }
                    "updateWidget" -> {
                        @Suppress("UNCHECKED_CAST")
                        val data = call.arguments as? Map<String, Any?> ?: emptyMap()
                        PickWidget.save(applicationContext, data)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun requestFrom(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("text/") != true) return null
                val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
                val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""
                if (text.isBlank() && subject.isBlank()) null
                else mapOf("type" to "share", "text" to text, "subject" to subject)
            }
            PickWidget.ACTION_OPEN -> {
                val route = intent.getStringExtra(PickWidget.EXTRA_ROUTE) ?: "/"
                mapOf("type" to "route", "route" to route)
            }
            else -> null
        }
    }

    companion object {
        const val CHANNEL = "unstuck/android"
    }
}
