package com.netflixpro.netflix_pro

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.GestureDetector
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.SeekBar
import android.widget.TextView
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import java.util.Locale
import kotlin.math.abs

@OptIn(UnstableApi::class)
class CinemaPlayerActivity : Activity() {

    private lateinit var playerView: PlayerView
    private lateinit var exoPlayer: ExoPlayer
    private lateinit var trackSelector: DefaultTrackSelector

    private lateinit var hudOverlay: FrameLayout
    private lateinit var loadingSpinner: ProgressBar
    private lateinit var titleText: TextView
    private lateinit var specBadge: TextView
    private lateinit var timeText: TextView
    private lateinit var seekBar: SeekBar
    private lateinit var playPauseBtn: Button
    private lateinit var presetBtn: Button
    private lateinit var aspectBtn: Button
    private lateinit var splitBtn: Button
    private lateinit var toastBadge: TextView

    private val cinemaEffect = CinemaPictureEffect()
    private val handler = Handler(Looper.getMainLooper())

    private var currentPreset = PicturePreset.VIVID_CINEMA
    private var effectsAttached: Boolean? = null
    private var splitCompare = false
    private var hudVisible = true
    private var isSeeking = false
    private var resizeIndex = 0
    private var currentSpeed = 1.0f

    private val resizeModes = listOf(
        AspectRatioFrameLayout.RESIZE_MODE_FIT to "FIT",
        AspectRatioFrameLayout.RESIZE_MODE_ZOOM to "ZOOM",
        AspectRatioFrameLayout.RESIZE_MODE_FILL to "STRETCH",
        AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH to "16:9",
        AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT to "4:3"
    )

    private val hideHudRunnable = Runnable { setHudVisible(false) }
    private val hideToastRunnable = Runnable { toastBadge.visibility = View.GONE }
    private val progressRunnable = object : Runnable {
        override fun run() {
            if (::exoPlayer.isInitialized && !isSeeking) {
                val dur = exoPlayer.duration.coerceAtLeast(0L)
                val pos = exoPlayer.currentPosition.coerceAtLeast(0L)
                if (dur > 0L) {
                    seekBar.max = 1000
                    seekBar.progress = ((pos * 1000L) / dur).toInt().coerceIn(0, 1000)
                }
                timeText.text = "${formatTime(pos)} / ${formatTime(dur)}"
            }
            handler.postDelayed(this, 500L)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.colorMode = ActivityInfo.COLOR_MODE_HDR
        }
        setContentView(R.layout.activity_cinema_player)
        enterImmersiveFullscreen()

        val root = findViewById<FrameLayout>(R.id.player_root)
        playerView = findViewById(R.id.player_view)

        val prefs = getSharedPreferences("cinema_player_prefs", Context.MODE_PRIVATE)
        val savedPresetName = prefs.getString("preset", PicturePreset.VIVID_CINEMA.name)
        currentPreset = runCatching { PicturePreset.valueOf(savedPresetName ?: "") }
            .getOrDefault(PicturePreset.VIVID_CINEMA)

        buildHudOverlay(root)
        setupTouchGestures(root)
        initPlayer()
    }

    private fun initPlayer() {
        val streamUrl = intent.getStringExtra("url")?.trim().orEmpty()
        val movieTitle = intent.getStringExtra("title")?.trim().orEmpty().ifEmpty { "Netflix Pro" }
        val userAgent = intent.getStringExtra("userAgent")?.trim().orEmpty()
            .ifEmpty { "Mozilla/5.0 (Windows NT 10.0; Win64; x64) CinemaTV/1.0" }

        titleText.text = movieTitle

        trackSelector = DefaultTrackSelector(this).apply {
            setParameters(
                buildUponParameters()
                    .setAllowVideoMixedMimeTypeAdaptiveness(true)
                    .setAllowAudioMixedMimeTypeAdaptiveness(true)
                    .setTunnelingEnabled(false)
            )
        }

        val httpFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(20_000)
            .setUserAgent(userAgent)

        val dataSourceFactory = DefaultDataSource.Factory(this, httpFactory)
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(15_000, 50_000, 1_500, 3_000)
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()

        val renderersFactory = DefaultRenderersFactory(this)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
            .setEnableDecoderFallback(true)

        exoPlayer = ExoPlayer.Builder(this, renderersFactory)
            .setTrackSelector(trackSelector)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSourceFactory))
            .setLoadControl(loadControl)
            .build()

        exoPlayer.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
                .build(),
            true
        )

        applyPicturePreset(currentPreset, reprepareIfNeeded = false)
        playerView.player = exoPlayer

        val lower = streamUrl.lowercase(Locale.ROOT)
        val itemBuilder = MediaItem.Builder()
            .setUri(Uri.parse(streamUrl))
            .setMediaMetadata(MediaMetadata.Builder().setTitle(movieTitle).build())

        when {
            lower.contains(".m3u8") -> itemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
            lower.contains(".mpd") -> itemBuilder.setMimeType(MimeTypes.APPLICATION_MPD)
        }

        exoPlayer.setMediaItem(itemBuilder.build())
        exoPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                loadingSpinner.visibility = if (state == Player.STATE_BUFFERING) View.VISIBLE else View.GONE
                if (state == Player.STATE_READY) {
                    updateTelemetryBadge()
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                playPauseBtn.text = if (isPlaying) "PAUSE" else "PLAY"
                if (isPlaying) scheduleHudHide() else handler.removeCallbacks(hideHudRunnable)
            }

            override fun onTracksChanged(tracks: androidx.media3.common.Tracks) {
                updateTelemetryBadge()
            }

            override fun onPlayerError(error: PlaybackException) {
                loadingSpinner.visibility = View.GONE
                showToastBadge("Playback Error: ${error.errorCodeName}")
            }
        })

        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
        handler.post(progressRunnable)
        scheduleHudHide()
    }

    private fun applyPicturePreset(preset: PicturePreset, reprepareIfNeeded: Boolean) {
        currentPreset = preset
        CinemaPictureState.settings = preset.settings
        presetBtn.text = preset.label
        getSharedPreferences("cinema_player_prefs", Context.MODE_PRIVATE)
            .edit().putString("preset", preset.name).apply()

        val shouldEnableEffect = preset.settings.enabled
        if (effectsAttached != shouldEnableEffect) {
            val pos = if (::exoPlayer.isInitialized) exoPlayer.currentPosition else 0L
            val playing = if (::exoPlayer.isInitialized) exoPlayer.playWhenReady else true
            exoPlayer.setVideoEffects(if (shouldEnableEffect) listOf(cinemaEffect) else emptyList())
            if (reprepareIfNeeded && ::exoPlayer.isInitialized) {
                exoPlayer.prepare()
                if (pos > 0L) exoPlayer.seekTo(pos)
                exoPlayer.playWhenReady = playing
            }
            effectsAttached = shouldEnableEffect
        }

        if (!shouldEnableEffect) {
            splitCompare = false
            CinemaPictureState.splitCompareX = 0f
            splitBtn.text = "SPLIT"
        }
        showToastBadge("Picture: ${preset.label}")
    }

    private fun updateTelemetryBadge() {
        val vf = exoPlayer.videoFormat
        val res = if (vf != null && vf.height > 0) "${vf.width}x${vf.height}" else "HD"
        val isHdr = vf?.colorInfo?.let {
            it.colorTransfer == C.COLOR_TRANSFER_ST2084 || it.colorTransfer == C.COLOR_TRANSFER_HLG
        } == true
        specBadge.text = if (isHdr) "$res • HDR" else "$res • ${currentPreset.label}"
    }

    private fun buildHudOverlay(root: FrameLayout) {
        loadingSpinner = ProgressBar(this).apply {
            isIndeterminate = true
            visibility = View.VISIBLE
        }
        root.addView(
            loadingSpinner,
            FrameLayout.LayoutParams(dp(52), dp(52), Gravity.CENTER)
        )

        toastBadge = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 14f
            setPadding(dp(18), dp(10), dp(18), dp(10))
            background = pillDrawable("#CC141414", "#E50914")
            visibility = View.GONE
        }
        root.addView(
            toastBadge,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.CENTER_HORIZONTAL
            ).apply { topMargin = dp(24) }
        )

        hudOverlay = FrameLayout(this)

        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(24), dp(18), dp(24), dp(18))
            setBackgroundColor(Color.parseColor("#99000000"))
        }

        val backBtn = makeHudButton("BACK") { finish() }
        titleText = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 18f
            setPadding(dp(14), 0, dp(10), 0)
            maxLines = 1
        }
        specBadge = TextView(this).apply {
            setTextColor(Color.parseColor("#46D369"))
            textSize = 12f
            setPadding(dp(10), dp(4), dp(10), dp(4))
            background = pillDrawable("#66000000", "#46D369")
        }

        presetBtn = makeHudButton(currentPreset.label) { openPictureMenu() }
        splitBtn = makeHudButton("SPLIT") {
            if (!currentPreset.settings.enabled) {
                showToastBadge("Enable Vivid/HDR preset first")
            } else {
                splitCompare = !splitCompare
                CinemaPictureState.splitCompareX = if (splitCompare) 0.5f else 0f
                splitBtn.text = if (splitCompare) "SPLIT ON" else "SPLIT"
                showToastBadge(if (splitCompare) "Left: Raw | Right: Enhanced" else "Split Off")
            }
        }
        val tracksBtn = makeHudButton("AUDIO / SUB") { openTracksDialog() }

        topBar.addView(backBtn)
        topBar.addView(titleText, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        topBar.addView(specBadge)
        topBar.addView(View(this), LinearLayout.LayoutParams(dp(10), 1))
        topBar.addView(presetBtn)
        topBar.addView(View(this), LinearLayout.LayoutParams(dp(8), 1))
        topBar.addView(splitBtn)
        topBar.addView(View(this), LinearLayout.LayoutParams(dp(8), 1))
        topBar.addView(tracksBtn)

        hudOverlay.addView(
            topBar,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
            )
        )

        val bottomBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(14), dp(24), dp(18))
            setBackgroundColor(Color.parseColor("#B3000000"))
        }

        seekBar = SeekBar(this).apply {
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser && ::exoPlayer.isInitialized) {
                        val dur = exoPlayer.duration.coerceAtLeast(0L)
                        exoPlayer.seekTo((dur * progress) / 1000L)
                    }
                }
                override fun onStartTrackingTouch(sb: SeekBar?) { isSeeking = true }
                override fun onStopTrackingTouch(sb: SeekBar?) {
                    isSeeking = false
                    scheduleHudHide()
                }
            })
        }
        bottomBox.addView(seekBar, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))

        val ctrlRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(8), 0, 0)
        }

        val rewBtn = makeHudButton("-15s") { seekBy(-15_000L) }
        playPauseBtn = makeHudButton("PAUSE", accent = true) { togglePlayPause() }
        val fwdBtn = makeHudButton("+15s") { seekBy(15_000L) }

        timeText = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 13f
            setPadding(dp(16), 0, 0, 0)
        }

        val speedBtn = makeHudButton("1.0x") {
            val speeds = listOf(1.0f, 1.25f, 1.5f, 2.0f, 0.75f)
            currentSpeed = speeds[(speeds.indexOf(currentSpeed) + 1) % speeds.size]
            exoPlayer.setPlaybackSpeed(currentSpeed)
            (it as Button).text = "${currentSpeed}x"
            showToastBadge("Speed: ${currentSpeed}x")
        }

        aspectBtn = makeHudButton("FIT") { cycleAspectRatio() }

        ctrlRow.addView(rewBtn)
        ctrlRow.addView(View(this), LinearLayout.LayoutParams(dp(8), 1))
        ctrlRow.addView(playPauseBtn)
        ctrlRow.addView(View(this), LinearLayout.LayoutParams(dp(8), 1))
        ctrlRow.addView(fwdBtn)
        ctrlRow.addView(timeText, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        ctrlRow.addView(speedBtn)
        ctrlRow.addView(View(this), LinearLayout.LayoutParams(dp(8), 1))
        ctrlRow.addView(aspectBtn)

        bottomBox.addView(ctrlRow)

        hudOverlay.addView(
            bottomBox,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        )

        root.addView(hudOverlay, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
    }

    private fun makeHudButton(label: String, accent: Boolean = false, onClick: (View) -> Unit): Button {
        return Button(this).apply {
            text = label
            setTextColor(Color.WHITE)
            textSize = 12f
            isAllCaps = false
            isFocusable = true
            isFocusableInTouchMode = false
            setPadding(dp(14), dp(6), dp(14), dp(6))
            background = pillDrawable(if (accent) "#E50914" else "#33FFFFFF", if (accent) "#FFFFFF" else "#66FFFFFF")
            setOnFocusChangeListener { v, hasFocus ->
                v.scaleX = if (hasFocus) 1.08f else 1.0f
                v.scaleY = if (hasFocus) 1.08f else 1.0f
                v.background = pillDrawable(
                    if (hasFocus) "#E50914" else if (accent) "#CC0914" else "#33FFFFFF",
                    if (hasFocus) "#FFFFFF" else "#66FFFFFF"
                )
            }
            setOnClickListener {
                onClick(it)
                scheduleHudHide()
            }
        }
    }

    private fun openPictureMenu() {
        val presets = PicturePreset.values()
        val names = presets.map {
            if (it == currentPreset) "✓ ${it.label}" else it.label
        }.toTypedArray()

        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Picture Quality Mode")
            .setItems(names) { _, which ->
                applyPicturePreset(presets[which], reprepareIfNeeded = true)
            }
            .setNeutralButton("Reset Vivid") { _, _ ->
                applyPicturePreset(PicturePreset.VIVID_CINEMA, reprepareIfNeeded = true)
            }
            .show()
    }

    private fun openTracksDialog() {
        val tracks = exoPlayer.currentTracks
        val options = mutableListOf<Pair<String, () -> Unit>>()

        options.add("Subtitles: OFF" to {
            exoPlayer.trackSelectionParameters = exoPlayer.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true).build()
        })

        tracks.groups.forEach { group ->
            for (i in 0 until group.length) {
                if (!group.isTrackSupported(i)) continue
                val fmt = group.getTrackFormat(i)
                val selected = if (group.isTrackSelected(i)) "✓ " else ""
                when (group.type) {
                    C.TRACK_TYPE_AUDIO -> {
                        val lang = fmt.language ?: "Track ${i + 1}"
                        options.add("${selected}Audio: ${fmt.label ?: lang}" to {
                            exoPlayer.trackSelectionParameters = exoPlayer.trackSelectionParameters.buildUpon()
                                .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
                                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i))
                                .build()
                        })
                    }
                    C.TRACK_TYPE_TEXT -> {
                        val lang = fmt.language ?: "Sub ${i + 1}"
                        options.add("${selected}Sub: ${fmt.label ?: lang}" to {
                            exoPlayer.trackSelectionParameters = exoPlayer.trackSelectionParameters.buildUpon()
                                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i))
                                .build()
                        })
                    }
                    C.TRACK_TYPE_VIDEO -> {
                        if (fmt.height > 0) {
                            options.add("${selected}Video: ${fmt.width}x${fmt.height}" to {
                                exoPlayer.trackSelectionParameters = exoPlayer.trackSelectionParameters.buildUpon()
                                    .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i))
                                    .build()
                            })
                        }
                    }
                }
            }
        }

        val labels = options.map { it.first }.toTypedArray()
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Audio, Video & Subtitles")
            .setItems(labels) { _, which -> options[which].second.invoke() }
            .show()
    }

    private fun setupTouchGestures(root: View) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val detector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                setHudVisible(!hudVisible)
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                if (e.x < root.width / 2f) seekBy(-15_000L) else seekBy(15_000L)
                return true
            }

            override fun onScroll(e1: MotionEvent?, e2: MotionEvent, dx: Float, dy: Float): Boolean {
                if (abs(dy) < abs(dx) || root.height <= 0) return false
                val delta = dy / root.height
                if (e2.x < root.width / 2f) {
                    val lp = window.attributes
                    val cur = if (lp.screenBrightness >= 0f) lp.screenBrightness else 0.5f
                    val next = (cur + delta * 1.4f).coerceIn(0.05f, 1.0f)
                    lp.screenBrightness = next
                    window.attributes = lp
                    showToastBadge("Brightness: ${(next * 100).toInt()}%")
                } else {
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                    val curVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    if (abs(dy) > 16f) {
                        val nextVol = (curVol + if (dy > 0) 1 else -1).coerceIn(0, maxVol)
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, nextVol, 0)
                        showToastBadge("Volume: ${(nextVol * 100) / maxVol}%")
                    }
                }
                return true
            }
        })

        root.setOnTouchListener { _, event ->
            detector.onTouchEvent(event)
            true
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                    togglePlayPause()
                    setHudVisible(true)
                    return true
                }
                KeyEvent.KEYCODE_DPAD_LEFT -> if (!hudVisible) {
                    seekBy(-15_000L)
                    return true
                }
                KeyEvent.KEYCODE_DPAD_RIGHT -> if (!hudVisible) {
                    seekBy(15_000L)
                    return true
                }
                KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> if (!hudVisible) {
                    togglePlayPause()
                    setHudVisible(true)
                    return true
                }
                KeyEvent.KEYCODE_DPAD_UP -> if (!hudVisible) {
                    setHudVisible(true)
                    openPictureMenu()
                    return true
                }
                KeyEvent.KEYCODE_DPAD_DOWN -> if (!hudVisible) {
                    cycleAspectRatio()
                    return true
                }
                KeyEvent.KEYCODE_BACK -> if (hudVisible) {
                    setHudVisible(false)
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun togglePlayPause() {
        if (exoPlayer.isPlaying) exoPlayer.pause() else exoPlayer.play()
    }

    private fun seekBy(deltaMs: Long) {
        val dur = exoPlayer.duration.coerceAtLeast(0L)
        val target = (exoPlayer.currentPosition + deltaMs).coerceIn(0L, if (dur > 0) dur else Long.MAX_VALUE)
        exoPlayer.seekTo(target)
        showToastBadge(if (deltaMs > 0) "+${deltaMs / 1000}s" else "${deltaMs / 1000}s")
    }

    private fun cycleAspectRatio() {
        resizeIndex = (resizeIndex + 1) % resizeModes.size
        val (mode, label) = resizeModes[resizeIndex]
        playerView.resizeMode = mode
        aspectBtn.text = label
        showToastBadge("Screen: $label")
    }

    private fun setHudVisible(visible: Boolean) {
        hudVisible = visible
        hudOverlay.visibility = if (visible) View.VISIBLE else View.GONE
        if (visible) {
            playPauseBtn.requestFocus()
            scheduleHudHide()
        } else {
            handler.removeCallbacks(hideHudRunnable)
        }
    }

    private fun scheduleHudHide() {
        handler.removeCallbacks(hideHudRunnable)
        if (::exoPlayer.isInitialized && exoPlayer.isPlaying) {
            handler.postDelayed(hideHudRunnable, 4500L)
        }
    }

    private fun showToastBadge(text: String) {
        toastBadge.text = text
        toastBadge.visibility = View.VISIBLE
        handler.removeCallbacks(hideToastRunnable)
        handler.postDelayed(hideToastRunnable, 1300L)
    }

    private fun enterImmersiveFullscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let {
                it.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )
        }
    }

    private fun pillDrawable(fillHex: String, strokeHex: String): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(10).toFloat()
            setColor(Color.parseColor(fillHex))
            setStroke(dp(1), Color.parseColor(strokeHex))
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun formatTime(ms: Long): String {
        if (ms <= 0L) return "00:00"
        val sec = ms / 1000L
        val h = sec / 3600L
        val m = (sec % 3600L) / 60L
        val s = sec % 60L
        return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s)
        else String.format(Locale.US, "%02d:%02d", m, s)
    }

    override fun onStop() {
        super.onStop()
        if (::exoPlayer.isInitialized) exoPlayer.pause()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        CinemaPictureState.splitCompareX = 0f
        if (::exoPlayer.isInitialized) exoPlayer.release()
        super.onDestroy()
    }
}
