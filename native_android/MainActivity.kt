
package com.netflixpro.netflix_pro

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pendingResult: MethodChannel.Result? = null

    private fun detectTvDevice(): Boolean {
        val uiMode = resources.configuration.uiMode and
                Configuration.UI_MODE_TYPE_MASK

        return uiMode == Configuration.UI_MODE_TYPE_TELEVISION ||
                packageManager.hasSystemFeature(
                    PackageManager.FEATURE_LEANBACK
                )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "playVideo") {

                val url = call.argument<String>("url").orEmpty().trim()
                val title = call.argument<String>("title")
                    .orEmpty()
                    .ifBlank { "Video Player" }

                val userAgent =
                    call.argument<String>("userAgent").orEmpty()

                val sourcesJson =
                    call.argument<String>("sourcesJson").orEmpty()

                val initialIndex =
                    call.argument<Int>("initialIndex") ?: 0

                val tmdbId =
                    call.argument<String>("tmdbId").orEmpty()

                val tmdbKey =
                    call.argument<String>("tmdbKey").orEmpty()

                val gistUrl =
                    call.argument<String>("gistUrl").orEmpty()

                // Flutter se diya gaya device mode priority lega.
                // Agar nahi diya gaya to device detect hoga.
                val isTv =
                    call.argument<Boolean>("isTv") ?: detectTvDevice()

                val season =
                    call.argument<Int>("season") ?: 1

                val episode =
                    call.argument<Int>("episode") ?: 1

                pendingResult?.success(false)
                pendingResult = result

                val intent = Intent(
                    this,
                    CinemaPlayerActivity::class.java
                ).apply {

                    putExtra("url", url)
                    putExtra("title", title)
                    putExtra("userAgent", userAgent)
                    putExtra("sourcesJson", sourcesJson)
                    putExtra("initialIndex", initialIndex)

                    putExtra("tmdbId", tmdbId)
                    putExtra("tmdbKey", tmdbKey)
                    putExtra("gistUrl", gistUrl)

                    putExtra("isTv", isTv)
                    putExtra("season", season)
                    putExtra("episode", episode)
                }

                startActivityForResult(intent, REQ_PLAYER)

            } else {
                result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        if (requestCode == REQ_PLAYER) {
            pendingResult?.success(
                resultCode == Activity.RESULT_OK ||
                        resultCode == Activity.RESULT_CANCELED
            )
            pendingResult = null
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val CHANNEL =
            "com.netflixpro.netflix_pro/player"

        private const val REQ_PLAYER = 9021
    }
}
