package com.netflixpro.netflix_pro

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.TypedValue
import android.view.GestureDetector
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
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
import org.json.JSONArray
import java.util.Locale
import kotlin.math.abs

@OptIn(UnstableApi::class)
class CinemaPlayerActivity : Activity() {

    private data class StreamSourceItem(
        val server: String,
        val title: String,
        val url: String,
        val isHindi: Boolean
    )

    private var player: ExoPlayer? = null
    private lateinit var trackSelector: DefaultTrackSelector
    private lateinit var playerView: PlayerView
    private lateinit var currentMediaItem: MediaItem

    private lateinit var hudContainer: FrameLayout
    private lateinit var unlockBtn: Button
    private lateinit var loadingSpinner: ProgressBar
    private lateinit var feedbackBadge: TextView
    private lateinit var titleView: TextView
    private lateinit var infoBadgeView: TextView
    private lateinit var playPauseBtn: Button
    private lateinit var aspectBtn: Button
    private lateinit var speedBtn: Button
    private lateinit var pictureBtn: Button
    private lateinit var sourcesBtn: Button
    private lateinit var timeCurrentView: TextView
    private lateinit var timeTotalView: TextView
    private lateinit var seekBar: SeekBar
    private lateinit var errorOverlay: LinearLayout
    private lateinit var errorMessageView: TextView

    // Sources Side Panel
    private lateinit var sourcesOverlay: FrameLayout
    private lateinit var sourcesListContainer: LinearLayout
    private var streamSources = mutableListOf<StreamSourceItem>()
    private var activeSourceIndex = 0
    private var currentUserAgent = "NetflixPro/1.0"
    private var currentMovieTitle = "Netflix Pro"

    private val handler = Handler(Looper.getMainLooper())
    private var hudVisible = true
    private var isScreenLocked = false
    private var isSeekingFromUser = false
    private var isShaderAttached = false

    private val resizeModes = intArrayOf(
        AspectRatioFrameLayout.RESIZE_MODE_FIT,
        AspectRatioFrameLayout.RESIZE_MODE_ZOOM,
        AspectRatioFrameLayout.RESIZE_MODE_FILL
    )
    private val resizeLabels = arrayOf("Fit", "Zoom", "Fill")
    private var resizeIndex = 0

    private val speeds = floatArrayOf(0.75f, 1.0f, 1.25f, 1.5f, 2.0f)
    private var speedIndex = 1

    private val prefs by lazy {
        getSharedPreferences("netflix_pro_player_prefs", Context.MODE_PRIVATE)
    }

    private val hideHudRunnable = Runnable { setHudVisible(false) }
    private val hideUnlockRunnable = Runnable { unlockBtn.visibility = View.GONE }
    private val hideFeedbackRunnable = Runnable { feedbackBadge.visibility = View.GONE }
    private val progressRunnable = object : Runnable {
        override fun run() {
            updateProgressUi()
            handler.postDelayed(this, 500)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.colorMode = ActivityInfo.COLOR_MODE_HDR
        }

        val savedName = prefs.getString("picture_preset_v2", PicturePreset.JUST_PLAYER.name)
        val initialPreset = PicturePreset.values().firstOrNull { it.name == savedName }
            ?: PicturePreset.JUST_PLAYER
        CinemaPictureEngineState.currentPreset = initialPreset

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val inflated = LayoutInflater.from(this).inflate(R.layout.activity_cinema_player, root, false)
        root.addView(inflated)

        val foundPlayerView = findPlayerView(root)
            ?: PlayerView(this).also {
                it.useController = false
                root.addView(it, 0)
            }
        playerView = foundPlayerView
        playerView.useController = false

        parseIncomingSources()
        buildGestureAndHudLayers(root)
        buildSourcesSidePanel(root)
        setContentView(root)
        enableImmersiveFullscreen()

        val rawUrl = intent.getStringExtra("url")?.trim().orEmpty()
        currentMovieTitle = intent.getStringExtra("title")?.trim().orEmpty().ifEmpty { "Netflix Pro" }
        currentUserAgent = intent.getStringExtra("userAgent")?.trim().orEmpty().ifEmpty { "NetflixPro/1.0" }

        val startUrl = if (streamSources.isNotEmpty()) {
            activeSourceIndex = activeSourceIndex.coerceIn(0, streamSources.size - 1)
            streamSources[activeSourceIndex].url
        } else {
            rawUrl
        }

        titleView.text = currentMovieTitle
        pictureBtn.text = if (initialPreset == PicturePreset.JUST_PLAYER) "Pure HDR" else initialPreset.displayName
        sourcesBtn.text = if (streamSources.isNotEmpty()) "Sources (${streamSources.size})" else "Sources"

        if (startUrl.isEmpty()) {
            showError("Stream URL खाली है।")
            return
        }

        initExoPlayer(startUrl, currentMovieTitle, currentUserAgent, initialPreset)
        scheduleHideHud()
    }

    private fun parseIncomingSources() {
        streamSources.clear()
        activeSourceIndex = intent.getIntExtra("initialIndex", 0)
        val jsonStr = intent.getStringExtra("sourcesJson")?.trim().orEmpty()
        if (jsonStr.isNotEmpty()) {
            try {
                val arr = JSONArray(jsonStr)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val u = obj.optString("url", "").trim()
                    if (u.isNotEmpty()) {
                        streamSources.add(
                            StreamSourceItem(
                                server = obj.optString("server", "Server ${i + 1}"),
                                title = obj.optString("title", "Stream ${i + 1}"),
                                url = u,
                                isHindi = obj.optBoolean("isHindi", false)
                            )
                        )
                    }
                }
            } catch (_: Exception) {}
        }
    }

    private fun findPlayerView(view: View): PlayerView? {
        if (view is PlayerView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findPlayerView(view.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun buildGestureAndHudLayers(root: FrameLayout) {
        val gestureLayer = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        setupTouchGestures(gestureLayer)
        root.addView(gestureLayer)

        loadingSpinner = ProgressBar(this).apply {
            layoutParams = FrameLayout.LayoutParams(dp(52), dp(52), Gravity.CENTER)
            visibility = View.VISIBLE
        }
        root.addView(loadingSpinner)

        feedbackBadge = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(18), dp(10), dp(18), dp(10))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#CC141414"))
                cornerRadius = dp(24).toFloat()
                setStroke(dp(1), Color.parseColor("#44FFFFFF"))
            }
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER_HORIZONTAL or Gravity.TOP
            ).apply {
                topMargin = dp(76)
            }
        }
        root.addView(feedbackBadge)

        hudContainer = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        // Top Bar (Clean & Spacious + Sources Button)
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(22))
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#DD000000"), Color.TRANSPARENT)
            )
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP
            )
        }

        val backBtn = createHudButton("← Back") { finish() }
        titleView = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setPadding(dp(12), 0, dp(10), 0)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        infoBadgeView = TextView(this).apply {
            text = "HDR"
            setTextColor(Color.parseColor("#46D369"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(8), dp(4), dp(8), dp(4))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#3346D369"))
                cornerRadius = dp(6).toFloat()
            }
            visibility = View.GONE
        }
        sourcesBtn = createHudButton("Sources") { openSourcesPanel() }.apply {
            background = createSourcesPill()
        }
        pictureBtn = createHudButton("Pure HDR") { showPicturePresetDialog() }
        val lockBtn = createHudButton("🔒 Lock") { lockScreen() }

        topBar.addView(backBtn)
        topBar.addView(titleView)
        topBar.addView(infoBadgeView)
        topBar.addView(spacer(dp(8)))
        topBar.addView(sourcesBtn)
        topBar.addView(spacer(dp(8)))
        topBar.addView(pictureBtn)
        topBar.addView(spacer(dp(8)))
        topBar.addView(lockBtn)
        hudContainer.addView(topBar)

        // Center Transport Buttons
        val centerBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        }
        val rwBtn = createHudButton("↺ 15s", big = true) { seekBy(-15_000L) }
        playPauseBtn = createHudButton("❚❚", big = true) { togglePlayPause() }
        val fwBtn = createHudButton("15s ↻", big = true) { seekBy(15_000L) }
        centerBar.addView(rwBtn)
        centerBar.addView(spacer(dp(20)))
        centerBar.addView(playPauseBtn)
        centerBar.addView(spacer(dp(20)))
        centerBar.addView(fwBtn)
        hudContainer.addView(centerBar)

        // Bottom Bar (Seekbar + Dedicated Action Buttons)
        val bottomPanel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(22), dp(20), dp(14))
            background = GradientDrawable(
                GradientDrawable.Orientation.BOTTOM_TOP,
                intArrayOf(Color.parseColor("#E6000000"), Color.TRANSPARENT)
            )
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        }

        val seekRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        timeCurrentView = TextView(this).apply {
            text = "00:00"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
        }
        seekBar = SeekBar(this).apply {
            max = 1000
            isFocusable = true
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                leftMargin = dp(12)
                rightMargin = dp(12)
            }
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) {
                        val dur = player?.duration ?: 0L
                        if (dur > 0) {
                            timeCurrentView.text = formatTime((dur * progress) / 1000L)
                        }
                    }
                }

                override fun onStartTrackingTouch(sb: SeekBar?) {
                    isSeekingFromUser = true
                    handler.removeCallbacks(hideHudRunnable)
                }

                override fun onStopTrackingTouch(sb: SeekBar?) {
                    isSeekingFromUser = false
                    val dur = player?.duration ?: 0L
                    if (dur > 0 && sb != null) {
                        player?.seekTo((dur * sb.progress) / 1000L)
                    }
                    scheduleHideHud()
                }
            })
        }
        timeTotalView = TextView(this).apply {
            text = "00:00"
            setTextColor(Color.parseColor("#B3FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
        }
        seekRow.addView(timeCurrentView)
        seekRow.addView(seekBar)
        seekRow.addView(timeTotalView)

        val actionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(10), 0, 0)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        val audioBtn = createHudButton("🔊 Audio") { showAudioDialog() }
        val subQualBtn = createHudButton("Sub / Quality") { showSubAndQualityDialog() }
        aspectBtn = createHudButton("Fit") { cycleAspectRatio() }
        speedBtn = createHudButton("1.0x") { cyclePlaybackSpeed() }

        actionsRow.addView(audioBtn)
        actionsRow.addView(spacer(dp(10)))
        actionsRow.addView(subQualBtn)
        actionsRow.addView(spacer(dp(10)))
        actionsRow.addView(aspectBtn)
        actionsRow.addView(spacer(dp(10)))
        actionsRow.addView(speedBtn)

        bottomPanel.addView(seekRow)
        bottomPanel.addView(actionsRow)
        hudContainer.addView(bottomPanel)

        root.addView(hudContainer)

        // Floating Unlock Button (Visible only when locked)
        unlockBtn = createHudButton("🔓 Unlock Screen", big = true) { unlockScreen() }.apply {
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            ).apply {
                bottomMargin = dp(32)
            }
        }
        root.addView(unlockBtn)

        // Error Overlay
        errorOverlay = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#E6000000"))
            setPadding(dp(24), dp(24), dp(24), dp(24))
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        errorMessageView = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
        }
        val retryBtn = createHudButton("Retry") {
            errorOverlay.visibility = View.GONE
            loadingSpinner.visibility = View.VISIBLE
            player?.prepare()
            player?.playWhenReady = true
        }
        val switchSrcErrBtn = createHudButton("Switch Source") {
            errorOverlay.visibility = View.GONE
            openSourcesPanel()
        }
        val closeBtn = createHudButton("Close") { finish() }
        val errBtns = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, 0)
            addView(retryBtn)
            if (streamSources.size > 1) {
                addView(spacer(dp(12)))
                addView(switchSrcErrBtn)
            }
            addView(spacer(dp(12)))
            addView(closeBtn)
        }
        errorOverlay.addView(errorMessageView)
        errorOverlay.addView(errBtns)
        root.addView(errorOverlay)
    }

    // =========================================================================
    // HOTSTAR / IPTV RIGHT SIDE PANEL: "Select Stream Source"
    // =========================================================================
    private fun buildSourcesSidePanel(root: FrameLayout) {
        sourcesOverlay = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#99000000"))
            visibility = View.GONE
            isClickable = true
            isFocusable = true
            setOnClickListener { closeSourcesPanel() }
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        val drawerWidth = (resources.displayMetrics.widthPixels * 0.48f)
            .toInt()
            .coerceIn(dp(310), dp(430))

        val drawer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#F20F1117"))
            setPadding(dp(18), dp(18), dp(18), dp(16))
            isClickable = true
            layoutParams = FrameLayout.LayoutParams(
                drawerWidth,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.END
            )
        }

        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val headerTexts = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val headerTitle = TextView(this).apply {
            text = "Select Stream Source"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.DEFAULT_BOLD
        }
        val headerSub = TextView(this).apply {
            text = "Hindi servers listed first • Tap to play"
            setTextColor(Color.parseColor("#F5C518"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(0, dp(2), 0, 0)
        }
        headerTexts.addView(headerTitle)
        headerTexts.addView(headerSub)

        val closeDrawerBtn = Button(this).apply {
            text = "✕"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            minWidth = 0
            minHeight = 0
            setPadding(dp(12), dp(6), dp(12), dp(6))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#2A2E39"))
            }
            setOnClickListener { closeSourcesPanel() }
        }

        headerRow.addView(headerTexts)
        headerRow.addView(closeDrawerBtn)
        drawer.addView(headerRow)

        val scrollView = ScrollView(this).apply {
            setPadding(0, dp(14), 0, 0)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        sourcesListContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        scrollView.addView(sourcesListContainer)
        drawer.addView(scrollView)
        sourcesOverlay.addView(drawer)
        root.addView(sourcesOverlay)
    }

    private fun openSourcesPanel() {
        handler.removeCallbacks(hideHudRunnable)
        refreshSourcesListUi()
        sourcesOverlay.visibility = View.VISIBLE
    }

    private fun closeSourcesPanel() {
        sourcesOverlay.visibility = View.GONE
        scheduleHideHud()
    }

    private fun refreshSourcesListUi() {
        sourcesListContainer.removeAllViews()

        if (streamSources.isEmpty()) {
            val emptyTxt = TextView(this).apply {
                text = "Single stream active"
                setTextColor(Color.parseColor("#99FFFFFF"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setPadding(dp(8), dp(24), dp(8), dp(8))
            }
            sourcesListContainer.addView(emptyTxt)
            return
        }

        streamSources.forEachIndexed { index, src ->
            val isSelected = index == activeSourceIndex

            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(14), dp(12), dp(14), dp(12))
                background = GradientDrawable().apply {
                    setColor(if (isSelected) Color.parseColor("#1A2B4C") else Color.parseColor("#161922"))
                    cornerRadius = dp(10).toFloat()
                    setStroke(
                        dp(if (isSelected) 2 else 1),
                        if (isSelected) Color.parseColor("#2E8B57") else Color.parseColor("#2C3240")
                    )
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = dp(10)
                }
                setOnClickListener {
                    switchToStreamSource(index)
                }
            }

            val leftCol = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }

            // Badges Row: [Server] [HINDI] [Quality]
            val badgesRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }

            val serverBadge = makeTagBadge(
                text = src.server,
                bgHex = if (src.server.contains("Livebox", true) || src.server.contains("IPTV", true)) "#16A34A" else "#2563EB",
                fgHex = "#FFFFFF"
            )
            badgesRow.addView(serverBadge)

            if (src.isHindi) {
                badgesRow.addView(spacer(dp(6)))
                badgesRow.addView(makeTagBadge("HINDI", "#FACC15", "#111111"))
            }

            val qTag = extractQualityTag(src.title)
            if (qTag.isNotEmpty()) {
                badgesRow.addView(spacer(dp(6)))
                badgesRow.addView(makeTagBadge(qTag, "#1E3A8A", "#93C5FD"))
            }

            val titleTxt = TextView(this).apply {
                text = if (src.isHindi) "${src.title} • Hindi" else src.title
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
                typeface = Typeface.DEFAULT_BOLD
                maxLines = 2
                ellipsize = TextUtils.TruncateAt.END
                setPadding(0, dp(7), dp(8), dp(3))
            }

            val subTxt = TextView(this).apply {
                text = "${src.server} • ${if (src.isHindi) "HINDI DUBBED / AUDIO" else "ORIGINAL HD"}"
                setTextColor(Color.parseColor("#8E96A4"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            }

            leftCol.addView(badgesRow)
            leftCol.addView(titleTxt)
            leftCol.addView(subTxt)

            val rightIcon = TextView(this).apply {
                text = if (isSelected) "✓" else "▶"
                gravity = Gravity.CENTER
                setTextColor(if (isSelected) Color.BLACK else Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                typeface = Typeface.DEFAULT_BOLD
                layoutParams = LinearLayout.LayoutParams(dp(26), dp(26))
                if (isSelected) {
                    background = GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        setColor(Color.parseColor("#22C55E"))
                    }
                }
            }

            card.addView(leftCol)
            card.addView(rightIcon)
            sourcesListContainer.addView(card)
        }
    }

    private fun makeTagBadge(text: String, bgHex: String, fgHex: String): TextView {
        return TextView(this).apply {
            this.text = text
            setTextColor(Color.parseColor(fgHex))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(7), dp(2), dp(7), dp(2))
            background = GradientDrawable().apply {
                setColor(Color.parseColor(bgHex))
                cornerRadius = dp(4).toFloat()
            }
        }
    }

    private fun extractQualityTag(title: String): String {
        val low = title.lowercase(Locale.ROOT)
        return when {
            low.contains("2160") || low.contains("4k") -> "4K UHD"
            low.contains("1080") -> "1080p FHD"
            low.contains("720") -> "720p HD"
            low.contains("480") -> "480p"
            else -> "HD"
        }
    }

    private fun switchToStreamSource(index: Int) {
        if (index !in streamSources.indices) return
        val exo = player ?: return
        activeSourceIndex = index
        val selected = streamSources[index]

        closeSourcesPanel()
        loadingSpinner.visibility = View.VISIBLE
        errorOverlay.visibility = View.GONE

        val lower = selected.url.lowercase(Locale.ROOT)
        val itemBuilder = MediaItem.Builder()
            .setUri(Uri.parse(selected.url))
            .setMediaMetadata(MediaMetadata.Builder().setTitle(currentMovieTitle).build())
        when {
            lower.contains(".m3u8") -> itemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
            lower.contains(".mpd") -> itemBuilder.setMimeType(MimeTypes.APPLICATION_MPD)
        }
        currentMediaItem = itemBuilder.build()

        exo.stop()
        exo.setMediaItem(currentMediaItem)
        exo.prepare()
        exo.playWhenReady = true
        showFeedback("Playing: ${selected.server}")
    }

    private fun createSourcesPill(): StateListDrawable {
        val focused = GradientDrawable().apply {
            setColor(Color.parseColor("#1D4ED8"))
            cornerRadius = dp(18).toFloat()
            setStroke(dp(2), Color.WHITE)
        }
        val normal = GradientDrawable().apply {
            setColor(Color.parseColor("#2563EB"))
            cornerRadius = dp(18).toFloat()
            setStroke(dp(1), Color.parseColor("#66FFFFFF"))
        }
        return StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_focused), focused)
            addState(intArrayOf(android.R.attr.state_pressed), focused)
            addState(intArrayOf(), normal)
        }
    }

    private fun lockScreen() {
        isScreenLocked = true
        setHudVisible(false)
        showUnlockPillTemporarily()
        showFeedback("Screen Locked")
    }

    private fun unlockScreen() {
        isScreenLocked = false
        handler.removeCallbacks(hideUnlockRunnable)
        unlockBtn.visibility = View.GONE
        setHudVisible(true)
        showFeedback("Screen Unlocked")
    }

    private fun showUnlockPillTemporarily() {
        unlockBtn.visibility = View.VISIBLE
        unlockBtn.requestFocus()
        handler.removeCallbacks(hideUnlockRunnable)
        handler.postDelayed(hideUnlockRunnable, 2800)
    }

    private fun initExoPlayer(url: String, title: String, userAgent: String, preset: PicturePreset) {
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

        val exo = ExoPlayer.Builder(this, renderersFactory)
            .setTrackSelector(trackSelector)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSourceFactory))
            .setLoadControl(loadControl)
            .build()

        val audioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
            .build()
        exo.setAudioAttributes(audioAttributes, true)

        if (preset.useShader) {
            exo.setVideoEffects(listOf(CinemaPictureEffect()))
            isShaderAttached = true
        } else {
            isShaderAttached = false
        }

        val lower = url.lowercase(Locale.ROOT)
        val itemBuilder = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setMediaMetadata(MediaMetadata.Builder().setTitle(title).build())
        when {
            lower.contains(".m3u8") -> itemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
            lower.contains(".mpd") -> itemBuilder.setMimeType(MimeTypes.APPLICATION_MPD)
        }
        currentMediaItem = itemBuilder.build()

        exo.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                loadingSpinner.visibility = if (state == Player.STATE_BUFFERING) View.VISIBLE else View.GONE
                updatePlayPauseLabel()
                updateProgressUi()
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                updatePlayPauseLabel()
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                updateInfoBadge()
            }

            override fun onTracksChanged(tracks: Tracks) {
                updateInfoBadge()
            }

            override fun onPlayerError(error: PlaybackException) {
                loadingSpinner.visibility = View.GONE
                // Agar pehla server fail ho toh automatically agle ready server par switch kare
                if (activeSourceIndex + 1 < streamSources.size) {
                    switchToStreamSource(activeSourceIndex + 1)
                } else {
                    showError("Playback Error: ${error.localizedMessage ?: error.errorCodeName}")
                }
            }
        })

        playerView.player = exo
        exo.setMediaItem(currentMediaItem)
        exo.prepare()
        exo.playWhenReady = true
        player = exo
        handler.post(progressRunnable)
    }

    private fun applyPicturePreset(preset: PicturePreset) {
        CinemaPictureEngineState.currentPreset = preset
        prefs.edit().putString("picture_preset_v2", preset.name).apply()
        pictureBtn.text = if (preset == PicturePreset.JUST_PLAYER) "Pure HDR" else preset.displayName

        val exo = player ?: return
        val needsShader = preset.useShader
        if (needsShader != isShaderAttached) {
            val pos = exo.currentPosition.coerceAtLeast(0L)
            val wasPlaying = exo.playWhenReady
            exo.stop()
            exo.setVideoEffects(if (needsShader) listOf(CinemaPictureEffect()) else emptyList())
            isShaderAttached = needsShader
            exo.setMediaItem(currentMediaItem, pos)
            exo.prepare()
            exo.playWhenReady = wasPlaying
        }
        showFeedback(preset.displayName)
    }

    private fun showPicturePresetDialog() {
        handler.removeCallbacks(hideHudRunnable)
        val presets = PicturePreset.values()
        val labels = presets.map { "${it.displayName}\n${it.tagline}" }.toTypedArray()
        val checked = presets.indexOf(CinemaPictureEngineState.currentPreset).coerceAtLeast(0)

        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Picture Quality Mode")
            .setSingleChoiceItems(labels, checked) { dialog, which ->
                applyPicturePreset(presets[which])
                dialog.dismiss()
                scheduleHideHud()
            }
            .setOnCancelListener { scheduleHideHud() }
            .show()
    }

    private fun showAudioDialog() {
        val exo = player ?: return
        handler.removeCallbacks(hideHudRunnable)
        val tracks = exo.currentTracks

        val labels = mutableListOf<String>()
        val actions = mutableListOf<() -> Unit>()
        var checkedIndex = 0

        labels.add("Auto (Default Audio)")
        actions.add {
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
                .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                .setPreferredAudioLanguage(null)
                .build()
            showFeedback("Audio: Auto")
        }

        tracks.groups.forEach { group ->
            if (group.type == C.TRACK_TYPE_AUDIO) {
                for (i in 0 until group.length) {
                    val fmt = group.getTrackFormat(i)
                    val supported = group.isTrackSupported(i)
                    val selected = group.isTrackSelected(i)
                    val ch = when (fmt.channelCount) {
                        1 -> "Mono"
                        2 -> "Stereo"
                        6 -> "5.1"
                        8 -> "7.1"
                        else -> if (fmt.channelCount > 0) "${fmt.channelCount}ch" else ""
                    }
                    val codec = fmt.sampleMimeType?.substringAfter("/")?.uppercase(Locale.ROOT) ?: ""
                    val titlePart = formatTrackName(fmt, "Audio Track ${labels.size}")
                    val meta = listOf(ch, codec).filter { it.isNotBlank() }.joinToString(" ")
                    val suffix = if (!supported) " [Device Unsupported]" else ""
                    val fullLabel = if (meta.isNotBlank()) "$titlePart ($meta)$suffix" else "$titlePart$suffix"

                    if (selected) checkedIndex = labels.size
                    labels.add(fullLabel)
                    actions.add {
                        if (!supported) {
                            showFeedback("Audio format unsupported by device")
                        } else {
                            val builder = exo.trackSelectionParameters.buildUpon()
                                .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
                                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i))
                            if (!fmt.language.isNullOrBlank()) {
                                builder.setPreferredAudioLanguage(fmt.language)
                            }
                            exo.trackSelectionParameters = builder.build()
                            showFeedback("Audio: $titlePart")
                        }
                    }
                }
            }
        }

        if (labels.size == 1) {
            labels.add("Single audio stream only")
            actions.add { }
        }

        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Audio Track")
            .setSingleChoiceItems(labels.toTypedArray(), checkedIndex) { dialog, which ->
                actions[which].invoke()
                dialog.dismiss()
                scheduleHideHud()
            }
            .setNegativeButton("Close") { dialog, _ ->
                dialog.dismiss()
                scheduleHideHud()
            }
            .setOnCancelListener { scheduleHideHud() }
            .show()
    }

    private fun showSubAndQualityDialog() {
        val exo = player ?: return
        handler.removeCallbacks(hideHudRunnable)
        val tracks = exo.currentTracks

        val items = mutableListOf<String>()
        val actions = mutableListOf<() -> Unit>()

        items.add("Subtitles: Off")
        actions.add {
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                .build()
            showFeedback("Subtitles Off")
        }
        tracks.groups.forEach { group ->
            if (group.type == C.TRACK_TYPE_TEXT) {
                for (i in 0 until group.length) {
                    if (group.isTrackSupported(i)) {
                        val fmt = group.getTrackFormat(i)
                        val selected = if (group.isTrackSelected(i)) "✓ " else ""
                        val name = formatTrackName(fmt, "Subtitle ${i + 1}")
                        items.add("${selected}Subtitle: $name")
                        actions.add {
                            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i))
                                .build()
                            showFeedback("Subtitle: $name")
                        }
                    }
                }
            }
        }

        items.add("Video Quality: Auto")
        actions.add {
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                .build()
            showFeedback("Quality: Auto")
        }
        tracks.groups.forEach { group ->
            if (group.type == C.TRACK_TYPE_VIDEO) {
                for (i in 0 until group.length) {
                    if (group.isTrackSupported(i)) {
                        val fmt = group.getTrackFormat(i)
                        val selected = if (group.isTrackSelected(i)) "✓ " else ""
                        val res = if (fmt.height > 0) "${fmt.width}x${fmt.height}" else "Video ${i + 1}"
                        items.add("${selected}Quality: $res")
                        actions.add {
                            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i))
                                .build()
                            showFeedback("Quality: $res")
                        }
                    }
                }
            }
        }

        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Subtitles & Video Quality")
            .setItems(items.toTypedArray()) { _, which ->
                actions[which].invoke()
                scheduleHideHud()
            }
            .setOnCancelListener { scheduleHideHud() }
            .show()
    }

    private fun formatTrackName(fmt: Format, fallback: String): String {
        val lang = fmt.language
            ?.takeIf { it.isNotBlank() && it != "und" }
            ?.let { Locale(it).displayLanguage }
            ?.takeIf { it.isNotBlank() }
        return listOfNotNull(fmt.label, lang).distinct().joinToString(" • ").ifBlank { fallback }
    }

    private fun setupTouchGestures(view: View) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)

        var startX = 0f
        var startY = 0f
        var draggingVertical = false
        var startVol = 0
        var startBrightness = 0.5f

        val detector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                if (isScreenLocked) {
                    showUnlockPillTemporarily()
                } else {
                    setHudVisible(!hudVisible)
                }
                return true
            }

            override fun onDoubleTap(e: MotionEvent): Boolean {
                if (isScreenLocked) {
                    showUnlockPillTemporarily()
                    return true
                }
                if (e.x < view.width / 2f) {
                    seekBy(-15_000L)
                } else {
                    seekBy(15_000L)
                }
                return true
            }
        })

        view.setOnTouchListener { v, event ->
            detector.onTouchEvent(event)
            if (isScreenLocked) return@setOnTouchListener true

            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = event.x
                    startY = event.y
                    draggingVertical = false
                    startVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val curB = window.attributes.screenBrightness
                    startBrightness = if (curB < 0f) 0.5f else curB
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.x - startX
                    val dy = startY - event.y
                    if (!draggingVertical && abs(dy) > dp(18) && abs(dy) > abs(dx)) {
                        draggingVertical = true
                    }
                    if (draggingVertical && v.height > 0) {
                        val deltaRatio = dy / (v.height * 0.65f)
                        if (startX < v.width / 2f) {
                            val newB = (startBrightness + deltaRatio).coerceIn(0.05f, 1.0f)
                            val lp = window.attributes
                            lp.screenBrightness = newB
                            window.attributes = lp
                            showFeedback("Brightness ${(newB * 100).toInt()}%")
                        } else {
                            val newVol = (startVol + deltaRatio * maxVol).toInt().coerceIn(0, maxVol)
                            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVol, 0)
                            showFeedback("Volume ${(newVol * 100) / maxVol}%")
                        }
                    }
                }
            }
            true
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (sourcesOverlay.visibility == View.VISIBLE) {
            if (keyCode == KeyEvent.KEYCODE_BACK) {
                closeSourcesPanel()
                return true
            }
            return super.onKeyDown(keyCode, event)
        }

        if (isScreenLocked) {
            if (keyCode == KeyEvent.KEYCODE_DPAD_CENTER || keyCode == KeyEvent.KEYCODE_ENTER) {
                if (unlockBtn.visibility == View.VISIBLE) {
                    unlockScreen()
                    return true
                }
            }
            showUnlockPillTemporarily()
            return true
        }

        return when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                togglePlayPause()
                setHudVisible(true)
                true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (!hudVisible) {
                    seekBy(-15_000L)
                    true
                } else {
                    scheduleHideHud()
                    super.onKeyDown(keyCode, event)
                }
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (!hudVisible) {
                    seekBy(15_000L)
                    true
                } else {
                    scheduleHideHud()
                    super.onKeyDown(keyCode, event)
                }
            }
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (!hudVisible) {
                    setHudVisible(true)
                    playPauseBtn.requestFocus()
                    true
                } else {
                    scheduleHideHud()
                    super.onKeyDown(keyCode, event)
                }
            }
            KeyEvent.KEYCODE_BACK -> {
                if (hudVisible) {
                    setHudVisible(false)
                    true
                } else {
                    finish()
                    true
                }
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }

    private fun togglePlayPause() {
        val exo = player ?: return
        if (exo.isPlaying) {
            exo.pause()
            showFeedback("Paused")
        } else {
            exo.play()
            showFeedback("Playing")
        }
        updatePlayPauseLabel()
        scheduleHideHud()
    }

    private fun seekBy(deltaMs: Long) {
        val exo = player ?: return
        val dur = exo.duration.takeIf { it > 0 } ?: Long.MAX_VALUE
        val target = (exo.currentPosition + deltaMs).coerceIn(0L, dur)
        exo.seekTo(target)
        showFeedback(if (deltaMs < 0) "↺ -15s" else "+15s ↻")
        updateProgressUi()
        if (hudVisible) scheduleHideHud()
    }

    private fun cycleAspectRatio() {
        resizeIndex = (resizeIndex + 1) % resizeModes.size
        playerView.resizeMode = resizeModes[resizeIndex]
        aspectBtn.text = resizeLabels[resizeIndex]
        showFeedback("Aspect: ${resizeLabels[resizeIndex]}")
        scheduleHideHud()
    }

    private fun cyclePlaybackSpeed() {
        speedIndex = (speedIndex + 1) % speeds.size
        val speed = speeds[speedIndex]
        player?.setPlaybackSpeed(speed)
        speedBtn.text = "${speed}x"
        showFeedback("Speed ${speed}x")
        scheduleHideHud()
    }

    private fun updateInfoBadge() {
        val vf = player?.videoFormat ?: return
        val resTag = when {
            vf.height >= 2160 -> "4K"
            vf.height >= 1440 -> "2K"
            vf.height >= 1080 -> "1080p"
            vf.height >= 720 -> "720p"
            vf.height > 0 -> "${vf.height}p"
            else -> ""
        }
        val hdrTag = when (vf.colorInfo?.colorTransfer) {
            C.COLOR_TRANSFER_ST2084 -> " • HDR10"
            C.COLOR_TRANSFER_HLG -> " • HLG"
            else -> ""
        }
        val badge = "$resTag$hdrTag".trim()
        if (badge.isNotEmpty()) {
            infoBadgeView.text = badge
            infoBadgeView.visibility = View.VISIBLE
        }
    }

    private fun updatePlayPauseLabel() {
        playPauseBtn.text = if (player?.isPlaying == true) "❚❚" else "▶"
    }

    private fun updateProgressUi() {
        val exo = player ?: return
        val dur = exo.duration
        val pos = exo.currentPosition.coerceAtLeast(0L)
        if (!isSeekingFromUser && dur > 0) {
            timeCurrentView.text = formatTime(pos)
            timeTotalView.text = formatTime(dur)
            seekBar.progress = ((pos * 1000L) / dur).toInt().coerceIn(0, 1000)
        }
    }

    private fun setHudVisible(visible: Boolean) {
        hudVisible = visible
        hudContainer.visibility = if (visible) View.VISIBLE else View.GONE
        handler.removeCallbacks(hideHudRunnable)
        if (visible && !isScreenLocked) scheduleHideHud()
    }

    private fun scheduleHideHud() {
        handler.removeCallbacks(hideHudRunnable)
        if (!isScreenLocked) {
            handler.postDelayed(hideHudRunnable, 4500)
        }
    }

    private fun showFeedback(msg: String) {
        feedbackBadge.text = msg
        feedbackBadge.visibility = View.VISIBLE
        handler.removeCallbacks(hideFeedbackRunnable)
        handler.postDelayed(hideFeedbackRunnable, 900)
    }

    private fun showError(msg: String) {
        errorMessageView.text = msg
        errorOverlay.visibility = View.VISIBLE
    }

    private fun createHudButton(label: String, big: Boolean = false, onClick: () -> Unit): Button {
        return Button(this).apply {
            text = label
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (big) 15f else 12f)
            typeface = Typeface.DEFAULT_BOLD
            isFocusable = true
            isFocusableInTouchMode = false
            minWidth = 0
            minHeight = 0
            setPadding(dp(if (big) 18 else 12), dp(if (big) 11 else 7), dp(if (big) 18 else 12), dp(if (big) 11 else 7))
            background = createFocusablePill()
            setOnClickListener { onClick() }
        }
    }

    private fun createFocusablePill(): StateListDrawable {
        val focused = GradientDrawable().apply {
            setColor(Color.parseColor("#E50914"))
            cornerRadius = dp(18).toFloat()
            setStroke(dp(2), Color.WHITE)
        }
        val normal = GradientDrawable().apply {
            setColor(Color.parseColor("#88181818"))
            cornerRadius = dp(18).toFloat()
            setStroke(dp(1), Color.parseColor("#33FFFFFF"))
        }
        return StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_focused), focused)
            addState(intArrayOf(android.R.attr.state_pressed), focused)
            addState(intArrayOf(), normal)
        }
    }

    private fun spacer(widthPx: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(widthPx, 1)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun formatTime(ms: Long): String {
        val totalSec = (ms / 1000L).coerceAtLeast(0L)
        val h = totalSec / 3600
        val m = (totalSec % 3600) / 60
        val s = totalSec % 60
        return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s)
        else String.format(Locale.US, "%02d:%02d", m, s)
    }

    private fun enableImmersiveFullscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                )
        }
    }

    override fun onPause() {
        super.onPause()
        player?.pause()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        player?.release()
        player = null
        super.onDestroy()
    }
}