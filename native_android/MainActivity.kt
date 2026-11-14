package com.netflixpro.netflix_pro

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "playVideo") {
                    val url = call.argument<String>("url").orEmpty().trim()
                    val title = call.argument<String>("title").orEmpty().ifBlank { "Netflix Pro" }
                    val userAgent = call.argument<String>("userAgent").orEmpty()
                    val sourcesJson = call.argument<String>("sourcesJson").orEmpty()
                    val initialIndex = call.argument<Int>("initialIndex") ?: 0

                    if (url.isEmpty() && sourcesJson.isEmpty()) {
                        result.error("INVALID_URL", "Empty stream URL", null)
                        return@setMethodCallHandler
                    }

                    pendingResult?.success(false)
                    pendingResult = result

                    val intent = Intent(this, CinemaPlayerActivity::class.java).apply {
                        putExtra("url", url)
                        putExtra("title", title)
                        putExtra("userAgent", userAgent)
                        putExtra("sourcesJson", sourcesJson)
                        putExtra("initialIndex", initialIndex)
                    }
                    startActivityForResult(intent, REQ_PLAYER)
                } else {
                    result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_PLAYER) {
            pendingResult?.success(resultCode == Activity.RESULT_OK || resultCode == Activity.RESULT_CANCELED)
            pendingResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val CHANNEL = "com.netflixpro.netflix_pro/player"
        private const val REQ_PLAYER = 9021
    }
}