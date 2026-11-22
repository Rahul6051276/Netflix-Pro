package com.netflixpro.netflix_pro

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.media.AudioManager
import android.media.audiofx.LoudnessEnhancer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.JsonReader
import android.util.JsonToken
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
import org.json.JSONObject
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.Collections
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread
import kotlin.math.abs

@OptIn(UnstableApi::class)
class CinemaPlayerActivity : Activity() {

    private data class StreamSourceItem(
        val server: String,
        val title: String,
        val url: String,
        val isHindi: Boolean,
        val isMultiAudio: Boolean = false
    )

    private var player: ExoPlayer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private lateinit var trackSelector: DefaultTrackSelector
    private lateinit var playerView: PlayerView
    private lateinit var currentMediaItem: MediaItem

    private lateinit var topHeaderCard: LinearLayout
    private lateinit var titleView: TextView
    private lateinit var badgeDecoderView: TextView
    private lateinit var badgeTypeView: TextView
    private lateinit var metaLineView: TextView

    private lateinit var centerStatusCard: LinearLayout
    private lateinit var centerStatusSpinner: ProgressBar
    private lateinit var centerStatusText: TextView
    private lateinit var centerStatusSub: TextView

    private lateinit var bottomHintsBar: LinearLayout
    private lateinit var sizeHintView: TextView
    private lateinit var sourcesHintView: TextView
    private lateinit var rightStatusHintView: TextView

    private lateinit var errorOverlay: LinearLayout
    private lateinit var errorMessageView: TextView

    // TV Menu Overlay (DOWN button: Sources | Picture & Size | Audio | Subtitles | Close)
    private lateinit var tvMenuOverlay: FrameLayout
    private lateinit var tabSourcesBtn: Button
    private lateinit var tabPictureBtn: Button
    private lateinit var tabAudioBtn: Button
    private lateinit var tabSubtitlesBtn: Button
    private lateinit var closeMenuBtn: Button
    private lateinit var menuContentContainer: LinearLayout
    private var activeMenuTab = 0 // 0=Sources, 1=Picture & Size, 2=Audio, 3=Subtitles

    private val streamSources = mutableListOf<StreamSourceItem>()
    private var activeSourceIndex = 0
    private var currentActiveUrl = ""
    private var currentUserAgent = "NetflixPro/1.0"
    private var currentMovieTitle = "Netflix Pro"
    private var currentPreset = PicturePreset.JUST_PLAYER

    private val handler = Handler(Looper.getMainLooper())
    private var isShaderAttached = false
    private var seekStepSec = 10
    private var seekStepMs = 10_000L
    @Volatile private var isActivityDestroyed = false
    @Volatile private var isResolvingAllSources = false

    private val boostLevels = intArrayOf(100, 135, 170, 200)
    private var boostIndex = 0
    private var currentBoostPercent = 100

    private val resizeModes = intArrayOf(
        AspectRatioFrameLayout.RESIZE_MODE_FIT,
        AspectRatioFrameLayout.RESIZE_MODE_ZOOM,
        AspectRatioFrameLayout.RESIZE_MODE_FILL
    )
    private val resizeLabels = arrayOf("Fit", "Crop / Zoom", "Fill")
    private var resizeIndex = 0

    private val prefs by lazy {
        getSharedPreferences("netflix_pro_player_prefs", Context.MODE_PRIVATE)
    }

    private val hideTransientUiRunnable = Runnable { hideTransientOverlayHints() }

    private fun isSafeUi(): Boolean = !isActivityDestroyed && !isFinishing && !isDestroyed

    private fun finishPlayerCleanly() {
        isActivityDestroyed = true
        handler.removeCallbacksAndMessages(null)
        releaseLoudnessEnhancer()
        try {
            playerView.player = null
            player?.stop()
            player?.release()
            player = null
        } catch (_: Throwable) {}
        setResult(Activity.RESULT_OK)
        finish()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        seekStepSec = intent.getIntExtra("seekSeconds", 10).coerceIn(5, 60)
        seekStepMs = seekStepSec * 1000L

        val savedName = prefs.getString("picture_preset_pure_hw", PicturePreset.JUST_PLAYER.name)
        currentPreset = PicturePreset.values().firstOrNull { it.name == savedName }
            ?: PicturePreset.JUST_PLAYER
        CinemaPictureEngineState.currentPreset = currentPreset

        val savedBoost = prefs.getInt("audio_boost_percent", 100).coerceIn(100, 200)
        currentBoostPercent = savedBoost
        boostIndex = boostLevels.indexOfFirst { it >= savedBoost }.let { if (it < 0) 0 else it }

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
        playerView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        )
        applyResizeModeToPlayer(resizeModes[resizeIndex])

        parseIncomingSources()
        buildTvScreenUi(root)
        buildTvSourcesAndSettingsMenu(root)
        setContentView(root)
        enableImmersiveFullscreen()

        val rawUrl = intent.getStringExtra("url")?.trim().orEmpty()
        currentMovieTitle = intent.getStringExtra("title")?.trim().orEmpty().ifEmpty { "Netflix Pro" }
        currentUserAgent = intent.getStringExtra("userAgent")?.trim().orEmpty().ifEmpty { "NetflixPro/1.0" }
        val tmdbId = intent.getStringExtra("tmdbId")?.trim().orEmpty()
        val tmdbKey = intent.getStringExtra("tmdbKey")?.trim().orEmpty()
        val customGistUrl = intent.getStringExtra("gistUrl")?.trim().orEmpty()
        val isTv = intent.getBooleanExtra("isTv", false)
        val season = intent.getIntExtra("season", 1)
        val episode = intent.getIntExtra("episode", 1)

        titleView.text = currentMovieTitle
        refreshTvHeaderAndHints()

        val directUrl = if (streamSources.isNotEmpty()) {
            activeSourceIndex = activeSourceIndex.coerceIn(0, streamSources.size - 1)
            streamSources[activeSourceIndex].url
        } else {
            rawUrl
        }

        if (directUrl.isNotEmpty()) {
            if (streamSources.isEmpty()) {
                streamSources.add(
                    StreamSourceItem(
                        server = "Gist Source",
                        title = currentMovieTitle,
                        url = directUrl,
                        isHindi = isExplicitHindi(currentMovieTitle)
                    )
                )
            }
            currentActiveUrl = directUrl
            refreshTvHeaderAndHints()
            showCenterCard("Playing stream...", "", showSpinner = true)
            initExoPlayer(directUrl, currentMovieTitle, currentUserAgent, currentPreset)
            scheduleHideTransientHints()
        } else if (tmdbId.isNotEmpty()) {
            refreshTvHeaderAndHints()
            showCenterCard(
                "Searching sources for $currentMovieTitle...",
                "Press ▼ DOWN for Sources",
                showSpinner = true
            )
            resolveStreamsInsidePlayer(tmdbId, tmdbKey, customGistUrl, currentMovieTitle, isTv, season, episode)
        } else {
            showError("Stream URL is empty.")
        }
    }

    private fun refreshTvHeaderAndHints() {
        if (!::metaLineView.isInitialized) return
        val active = streamSources.getOrNull(activeSourceIndex)
        val isIptv = active != null && isIptvSource(active)
        badgeTypeView.text = if (isIptv) "XTREAM" else "STREMIO"
        badgeTypeView.setBackgroundColor(
            Color.parseColor(if (isIptv) "#0284C7" else "#4F46E5")
        )
        metaLineView.text = if (active != null) {
            "${active.server} • ${active.title}"
        } else {
            "Gist Sources"
        }
        sizeHintView.text = "▲ UP: Size (${resizeLabels[resizeIndex]})"
        val iptvCount = streamSources.count { isIptvSource(it) }
        sourcesHintView.text = "▼ DOWN: Sources (${streamSources.size} • $iptvCount IPTV) • Picture • Audio"
        rightStatusHintView.text = if (active != null) {
            "${active.server} (${(activeSourceIndex + 1).coerceAtLeast(1)}/${streamSources.size.coerceAtLeast(1)})"
        } else {
            "Press ▼ DOWN for Sources"
        }
    }

    private fun showCenterCard(title: String, subtitle: String, showSpinner: Boolean) {
        centerStatusText.text = title
        if (subtitle.isNotEmpty()) {
            centerStatusSub.text = subtitle
            centerStatusSub.visibility = View.VISIBLE
        } else {
            centerStatusSub.visibility = View.GONE
        }
        centerStatusSpinner.visibility = if (showSpinner) View.VISIBLE else View.GONE
        centerStatusCard.visibility = View.VISIBLE
        topHeaderCard.visibility = View.VISIBLE
        bottomHintsBar.visibility = View.VISIBLE
    }

    private fun hideTransientOverlayHints() {
        if (!isSafeUi() || tvMenuOverlay.visibility == View.VISIBLE) return
        if (centerStatusSpinner.visibility != View.VISIBLE) {
            centerStatusCard.visibility = View.GONE
        }
        topHeaderCard.visibility = View.GONE
        bottomHintsBar.visibility = View.GONE
    }

    private fun scheduleHideTransientHints() {
        handler.removeCallbacks(hideTransientUiRunnable)
        if (isSafeUi() && tvMenuOverlay.visibility != View.VISIBLE) {
            handler.postDelayed(hideTransientUiRunnable, 4500)
        }
    }

    private fun parseIncomingSources() {
        try {
            val rawJson = intent.getStringExtra("sourcesJson")?.trim().orEmpty()
            if (rawJson.startsWith("[")) {
                val arr = JSONArray(rawJson)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val sUrl = obj.optString("url", "").trim()
                    if (sUrl.isNotEmpty()) {
                        val srv = obj.optString("server", "Server")
                        val ttl = obj.optString("title", currentMovieTitle)
                        val hin = obj.optBoolean("isHindi", isExplicitHindi("$srv $ttl"))
                        val multi = obj.optBoolean("isMultiAudio", isIndianMultiAudioServer("$srv $ttl"))
                        streamSources.add(StreamSourceItem(srv, ttl, sUrl, hin, multi))
                    }
                }
            }
            activeSourceIndex = if (intent.hasExtra("initialIndex")) {
                intent.getIntExtra("initialIndex", 0)
            } else {
                intent.getIntExtra("activeIndex", 0)
            }
        } catch (_: Throwable) {}
    }

    private fun attachLoudnessEnhancer(audioSessionId: Int) {
        if (audioSessionId <= 0 || audioSessionId == C.AUDIO_SESSION_ID_UNSET) return
        releaseLoudnessEnhancer()
        try {
            loudnessEnhancer = LoudnessEnhancer(audioSessionId)
            applyAudioBoostPercent(currentBoostPercent, showToast = false)
        } catch (_: Throwable) {
            loudnessEnhancer = null
        }
    }

    private fun releaseLoudnessEnhancer() {
        try {
            loudnessEnhancer?.enabled = false
            loudnessEnhancer?.release()
        } catch (_: Throwable) {}
        loudnessEnhancer = null
    }

    private fun applyAudioBoostPercent(percent: Int, showToast: Boolean = true) {
        val clamped = percent.coerceIn(100, 200)
        currentBoostPercent = clamped
        prefs.edit().putInt("audio_boost_percent", clamped).apply()

        val exo = player
        if (exo != null && loudnessEnhancer == null) {
            val sid = exo.audioSessionId
            if (sid > 0 && sid != C.AUDIO_SESSION_ID_UNSET) {
                try {
                    loudnessEnhancer = LoudnessEnhancer(sid)
                } catch (_: Throwable) {}
            }
        }

        try {
            val enhancer = loudnessEnhancer
            if (enhancer != null) {
                if (clamped <= 100) {
                    enhancer.setTargetGain(0)
                    enhancer.enabled = false
                } else {
                    val gainMb = ((clamped - 100) * 15).coerceIn(0, 1500)
                    enhancer.setTargetGain(gainMb)
                    enhancer.enabled = true
                }
            }
        } catch (_: Throwable) {}

        if (showToast) {
            showCenterCard("Audio Boost: $clamped%", "Press ▼ DOWN for menu", showSpinner = false)
            scheduleHideTransientHints()
        }
    }

    private fun resolveStreamsInsidePlayer(
        tmdbId: String,
        tmdbKey: String,
        customGistUrl: String,
        movieTitle: String,
        isTv: Boolean,
        season: Int,
        episode: Int
    ) {
        isResolvingAllSources = true
        thread(start = true) {
            val found = Collections.synchronizedList(mutableListOf<StreamSourceItem>())
            val playbackStarted = AtomicBoolean(false)
            val cleanTarget = cleanText(movieTitle)
            var imdbId = ""

            fun syncSourcesToUi(isFinal: Boolean = false) {
                val snapshot = synchronized(found) {
                    found.distinctBy { it.url }.toMutableList()
                }
                snapshot.sortWith(
                    compareByDescending<StreamSourceItem> { sourcePriorityScore(it) }
                        .thenByDescending { qualityScore(it.title) }
                )
                if (snapshot.size > 60) {
                    snapshot.subList(60, snapshot.size).clear()
                }

                handler.post {
                    if (!isSafeUi()) return@post
                    streamSources.clear()
                    streamSources.addAll(snapshot)

                    if (currentActiveUrl.isNotEmpty()) {
                        val idx = streamSources.indexOfFirst { it.url == currentActiveUrl }
                        if (idx >= 0) activeSourceIndex = idx
                    }

                    refreshTvHeaderAndHints()
                    if (tvMenuOverlay.visibility == View.VISIBLE && activeMenuTab == 0) {
                        refreshMenuBody()
                    }

                    if (streamSources.isNotEmpty() && playbackStarted.compareAndSet(false, true)) {
                        activeSourceIndex = 0
                        currentActiveUrl = streamSources[0].url
                        refreshTvHeaderAndHints()
                        showCenterCard(
                            "Found ${streamSources.size} source(s) • Press ▼ DOWN for Sources",
                            "${streamSources[0].server} • ${streamSources[0].title}",
                            showSpinner = true
                        )
                        initExoPlayer(
                            currentActiveUrl,
                            currentMovieTitle,
                            currentUserAgent,
                            currentPreset
                        )
                        scheduleHideTransientHints()
                    }
                }
            }

            if (tmdbKey.isNotEmpty()) {
                try {
                    val extType = if (isTv) "tv" else "movie"
                    val extStr = httpGet(
                        "https://api.themoviedb.org/3/$extType/$tmdbId/external_ids?api_key=$tmdbKey",
                        6000
                    )
                    if (extStr.isNotEmpty()) {
                        imdbId = JSONObject(extStr).optString("imdb_id", "")
                    }
                } catch (_: Throwable) {}
            }

            val providers = mutableListOf<JSONObject>()
            if (customGistUrl.isNotEmpty()) {
                try {
                    val sep = if (customGistUrl.contains("?")) "&" else "?"
                    val gistUrl = "$customGistUrl${sep}t=${System.currentTimeMillis()}"
                    val gistStr = httpGet(gistUrl, 10_000)
                    if (gistStr.isNotEmpty()) {
                        val trimmed = gistStr.trim()
                        val arr = if (trimmed.startsWith("[")) {
                            JSONArray(trimmed)
                        } else {
                            val obj = JSONObject(trimmed)
                            obj.optJSONArray("active_providers")
                                ?: obj.optJSONArray("providers")
                                ?: JSONArray()
                        }
                        for (i in 0 until arr.length()) {
                            providers.add(arr.getJSONObject(i))
                        }
                    }
                } catch (_: Throwable) {}
            }

            val latch = CountDownLatch(providers.size.coerceAtLeast(1))

            if (providers.isEmpty()) {
                latch.countDown()
            } else {
                for (prov in providers) {
                    thread(start = true) {
                        try {
                            if (!isSafeUi()) return@thread
                            val type = prov.optString("type", "")
                            val provName = prov.optString("name", "Server")

                            if (type == "xtream") {
                                val host = prov.optString("xc_host", prov.optString("host", "")).trimEnd('/')
                                val user = prov.optString("xc_username", prov.optString("username", ""))
                                val pass = prov.optString("xc_password", prov.optString("password", ""))

                                if (host.isNotEmpty() && user.isNotEmpty() && pass.isNotEmpty()) {
                                    if (isTv) {
                                        val cands = streamSearchXtreamList(
                                            apiUrl = "$host/player_api.php?username=$user&password=$pass&action=get_series",
                                            tmdbId = tmdbId,
                                            cleanTarget = cleanTarget,
                                            idKey = "series_id"
                                        )
                                        cands.sortByDescending { if (it.isHindi) 1 else 0 }
                                        for (bestSeries in cands) {
                                            if (!isSafeUi()) break
                                            val infoStr = httpGet(
                                                "$host/player_api.php?username=$user&password=$pass&action=get_series_info&series_id=${bestSeries.id}",
                                                15_000,
                                                userAgent = "IPTVSmartersPro"
                                            )
                                            if (infoStr.startsWith("{")) {
                                                val epMap = JSONObject(infoStr).optJSONObject("episodes")
                                                val epArr = epMap?.optJSONArray("$season")
                                                if (epArr != null) {
                                                    for (j in 0 until epArr.length()) {
                                                        val epObj = epArr.getJSONObject(j)
                                                        if (epObj.optInt("episode_num", -1) == episode) {
                                                            val eid = epObj.optString("id", "")
                                                            val ext = epObj.optString("container_extension", "mp4").ifBlank { "mp4" }
                                                            found.add(
                                                                StreamSourceItem(
                                                                    server = provName.ifBlank { "Xtream" },
                                                                    title = if (bestSeries.isHindi) "$movieTitle (Hindi) S$season:E$episode" else "$movieTitle S$season:E$episode",
                                                                    url = "$host/series/$user/$pass/$eid.$ext",
                                                                    isHindi = bestSeries.isHindi,
                                                                    isMultiAudio = false
                                                                )
                                                            )
                                                            syncSourcesToUi(isFinal = false)
                                                            break
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        val cands = streamSearchXtreamList(
                                            apiUrl = "$host/player_api.php?username=$user&password=$pass&action=get_vod_streams",
                                            tmdbId = tmdbId,
                                            cleanTarget = cleanTarget,
                                            idKey = "stream_id"
                                        )
                                        cands.sortByDescending { if (it.isHindi) 1 else 0 }
                                        for (bestMovie in cands) {
                                            found.add(
                                                StreamSourceItem(
                                                    server = provName.ifBlank { "Xtream" },
                                                    title = bestMovie.name.ifBlank { movieTitle },
                                                    url = "$host/movie/$user/$pass/${bestMovie.id}.${bestMovie.ext}",
                                                    isHindi = bestMovie.isHindi,
                                                    isMultiAudio = false
                                                )
                                            )
                                        }
                                        if (cands.isNotEmpty()) syncSourcesToUi(isFinal = false)
                                    }
                                }
                            } else if (type == "stremio" && imdbId.isNotEmpty()) {
                                val base = prov.optString("url", "").replace("/manifest.json", "")
                                val streamPath = if (isTv) {
                                    "$base/stream/series/$imdbId:$season:$episode.json"
                                } else {
                                    "$base/stream/movie/$imdbId.json"
                                }
                                val sStr = httpGet(streamPath, 12_000)
                                if (sStr.startsWith("{")) {
                                    val entries = JSONObject(sStr).optJSONArray("streams")
                                    if (entries != null) {
                                        var addedAny = false
                                        for (i in 0 until entries.length()) {
                                            val sObj = entries.getJSONObject(i)
                                            val sUrl = sObj.optString("url", "").trim()
                                            if (sUrl.isEmpty()) continue
                                            val namePart = sObj.optString("name", "")
                                            val titlePart = sObj.optString("title", "")
                                            val combined = "$namePart $titlePart".trim()
                                            val low = combined.lowercase(Locale.ROOT)
                                            if (low.contains("donation") || low.contains("discord") || low.contains("telegram")) continue

                                            val displayTitle = titlePart.ifBlank { namePart }.ifBlank { "$movieTitle HD" }
                                            val explicitHindi = isExplicitHindi("$provName $combined")
                                            val multiHindi = isIndianMultiAudioServer("$provName $combined")

                                            found.add(
                                                StreamSourceItem(
                                                    server = provName.ifBlank { "Stremio" },
                                                    title = displayTitle,
                                                    url = sUrl,
                                                    isHindi = explicitHindi || multiHindi,
                                                    isMultiAudio = multiHindi && !explicitHindi
                                                )
                                            )
                                            addedAny = true
                                        }
                                        if (addedAny) syncSourcesToUi(isFinal = false)
                                    }
                                }
                            }
                        } catch (_: Throwable) {
                        } finally {
                            latch.countDown()
                        }
                    }
                }
            }

            try {
                latch.await(30, TimeUnit.SECONDS)
            } catch (_: Throwable) {}

            isResolvingAllSources = false
            syncSourcesToUi(isFinal = true)

            handler.post {
                if (!isSafeUi()) return@post
                if (streamSources.isEmpty()) {
                    centerStatusCard.visibility = View.GONE
                    showError("No stream sources found for this title.")
                }
            }
        }
    }

    private data class XtreamCandidate(
        val id: String,
        val name: String,
        val ext: String,
        val isHindi: Boolean
    )

    private fun streamSearchXtreamList(
        apiUrl: String,
        tmdbId: String,
        cleanTarget: String,
        idKey: String
    ): MutableList<XtreamCandidate> {
        val matches = mutableListOf<XtreamCandidate>()
        var conn: HttpURLConnection? = null
        try {
            conn = (URL(apiUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 35_000
                requestMethod = "GET"
                setRequestProperty("User-Agent", "IPTVSmartersPro")
            }
            if (conn.responseCode !in 200..299) return matches

            JsonReader(InputStreamReader(conn.inputStream, "UTF-8")).use { reader ->
                reader.isLenient = true
                if (reader.peek() != JsonToken.BEGIN_ARRAY) return matches
                reader.beginArray()
                while (reader.hasNext()) {
                    if (!isSafeUi()) break
                    if (reader.peek() != JsonToken.BEGIN_OBJECT) {
                        reader.skipValue()
                        continue
                    }
                    var itemId = ""
                    var itemName = ""
                    var itemCat = ""
                    var itemTmdb = ""
                    var itemExt = "mp4"

                    reader.beginObject()
                    while (reader.hasNext()) {
                        val key = reader.nextName()
                        if (reader.peek() == JsonToken.NULL) {
                            reader.nextNull()
                            continue
                        }
                        when (key) {
                            idKey -> itemId = readScalarAsString(reader)
                            "name" -> itemName = readScalarAsString(reader)
                            "category_name" -> itemCat = readScalarAsString(reader)
                            "tmdb_id", "tmdb" -> itemTmdb = readScalarAsString(reader)
                            "container_extension" -> {
                                val v = readScalarAsString(reader)
                                if (v.isNotBlank()) itemExt = v
                            }
                            else -> reader.skipValue()
                        }
                    }
                    reader.endObject()

                    if (itemId.isNotEmpty()) {
                        val sClean = cleanText(itemName)
                        val tmdbMatch = itemTmdb.isNotEmpty() && itemTmdb == tmdbId
                        val titleMatch = sClean.length >= 3 && cleanTarget.length >= 3 && (
                            sClean == cleanTarget ||
                            (cleanTarget.length >= 4 && sClean.contains(cleanTarget))
                        )
                        if (tmdbMatch || titleMatch) {
                            matches.add(
                                XtreamCandidate(
                                    id = itemId,
                                    name = itemName,
                                    ext = itemExt,
                                    isHindi = isExplicitHindi("$itemName $itemCat")
                                )
                            )
                        }
                    }
                }
            }
        } catch (_: Throwable) {
        } finally {
            try { conn?.disconnect() } catch (_: Throwable) {}
        }
        return matches
    }

    private fun readScalarAsString(reader: JsonReader): String {
        return when (reader.peek()) {
            JsonToken.STRING -> reader.nextString()
            JsonToken.NUMBER -> reader.nextString()
            JsonToken.BOOLEAN -> reader.nextBoolean().toString()
            else -> {
                reader.skipValue()
                ""
            }
        }
    }

    private fun isIptvSource(item: StreamSourceItem): Boolean {
        val urlLow = item.url.lowercase(Locale.ROOT)
        return urlLow.contains("/movie/") || urlLow.contains("/series/") ||
            item.server.contains("xtream", true) || item.server.contains("iptv", true) ||
            item.server.contains("livebox", true) || item.server.contains("ott", true)
    }

    private fun sourcePriorityScore(item: StreamSourceItem): Int {
        val isIptv = isIptvSource(item)
        return when {
            isIptv && item.isHindi -> 110
            isIptv -> 95
            item.isHindi && !item.isMultiAudio -> 85
            item.isMultiAudio -> 75
            else -> 20
        }
    }

    private fun qualityScore(title: String): Int {
        val low = title.lowercase(Locale.ROOT)
        return when {
            low.contains("1080") -> 4
            low.contains("720") -> 3
            low.contains("2160") || low.contains("4k") -> 2
            else -> 1
        }
    }

    private fun httpGet(urlStr: String, timeoutMs: Int, userAgent: String = "Mozilla/5.0"): String {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                connectTimeout = timeoutMs
                readTimeout = timeoutMs
                requestMethod = "GET"
                setRequestProperty("User-Agent", userAgent)
            }
            if (conn.responseCode in 200..299) {
                conn.inputStream.bufferedReader().use { it.readText() }
            } else {
                ""
            }
        } catch (_: Throwable) {
            ""
        } finally {
            try { conn?.disconnect() } catch (_: Throwable) {}
        }
    }

    private fun isExplicitHindi(text: String): Boolean {
        val low = text.lowercase(Locale.ROOT)
        return low.contains("hindi") || low.contains("dual") ||
            low.contains("multi") || low.contains("dubbed") ||
            low.contains("(hin)") || low.contains("[hin]") ||
            low.contains(" hin ") || low.startsWith("in ") || low.contains("in |") || low.contains("in -")
    }

    private fun isIndianMultiAudioServer(text: String): Boolean {
        val low = text.lowercase(Locale.ROOT)
        return low.contains("penguplay") || low.contains("4khdhub") ||
            low.contains("hdhub4u") || low.contains("vegamovies") ||
            low.contains("moviesmod") || low.contains("uhdmovies") ||
            low.contains("bollyflix") || low.contains("desiremovies")
    }

    private fun cleanText(text: String): String =
        text.lowercase(Locale.ROOT)
            .replace(Regex("\\(\\d{4}\\)"), "")
            .replace(Regex("[^a-z0-9]"), "")
            .trim()

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

    private fun findAspectFrameLayout(view: View): AspectRatioFrameLayout? {
        if (view is AspectRatioFrameLayout) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findAspectFrameLayout(view.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun applyResizeModeToPlayer(mode: Int) {
        if (!::playerView.isInitialized) return
        playerView.resizeMode = mode
        findAspectFrameLayout(playerView)?.let { aspectFrame ->
            aspectFrame.resizeMode = mode
            aspectFrame.layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            )
            for (i in 0 until aspectFrame.childCount) {
                val child = aspectFrame.getChildAt(i)
                child.layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    Gravity.CENTER
                )
            }
            aspectFrame.requestLayout()
            aspectFrame.invalidate()
        }
        playerView.requestLayout()
        playerView.invalidate()
    }

    private fun buildTvScreenUi(root: FrameLayout) {
        val gestureLayer = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setOnClickListener {
                if (tvMenuOverlay.visibility == View.VISIBLE) {
                    closeTvMenu()
                } else {
                    openTvMenu(initialTab = 0)
                }
            }
        }
        setupTvTouchGestures(gestureLayer)
        root.addView(gestureLayer)

        topHeaderCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(18), dp(24), dp(14))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START
            )
        }
        titleView = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }
        val badgesRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(4), 0, 0)
        }
        badgeDecoderView = TextView(this).apply {
            text = "HW DECODER"
            setTextColor(Color.parseColor("#4ADE80"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(6), dp(2), dp(6), dp(2))
            setBackgroundColor(Color.parseColor("#3316A34A"))
        }
        badgeTypeView = TextView(this).apply {
            text = "XTREAM"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(6), dp(2), dp(6), dp(2))
            setBackgroundColor(Color.parseColor("#0284C7"))
        }
        metaLineView = TextView(this).apply {
            setTextColor(Color.parseColor("#E5E7EB"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setPadding(dp(8), 0, 0, 0)
        }
        badgesRow.addView(badgeDecoderView)
        badgesRow.addView(spacer(dp(6)))
        badgesRow.addView(badgeTypeView)
        badgesRow.addView(metaLineView)
        topHeaderCard.addView(titleView)
        topHeaderCard.addView(badgesRow)
        root.addView(topHeaderCard)

        centerStatusCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(34), dp(22), dp(34), dp(22))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E6141821"))
                cornerRadius = dp(12).toFloat()
            }
            visibility = View.GONE
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
        }
        centerStatusSpinner = ProgressBar(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(24), dp(24)).apply {
                bottomMargin = dp(10)
            }
        }
        centerStatusText = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        centerStatusSub = TextView(this).apply {
            setTextColor(Color.parseColor("#D1D5DB"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            gravity = Gravity.CENTER
            setPadding(0, dp(4), 0, 0)
            visibility = View.GONE
        }
        centerStatusCard.addView(centerStatusSpinner)
        centerStatusCard.addView(centerStatusText)
        centerStatusCard.addView(centerStatusSub)
        root.addView(centerStatusCard)

        bottomHintsBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(22), dp(10), dp(22), dp(12))
            setBackgroundColor(Color.parseColor("#88000000"))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        }
        val okHint = TextView(this).apply {
            text = "▶ OK: Play"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
        }
        val seekHint = TextView(this).apply {
            text = "◄/►: ±${seekStepSec}s"
            setTextColor(Color.parseColor("#E5E7EB"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setPadding(dp(12), 0, dp(12), 0)
        }
        sizeHintView = TextView(this).apply {
            text = "▲ UP: Size (Fit)"
            setTextColor(Color.parseColor("#E5E7EB"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setPadding(0, 0, dp(12), 0)
        }
        sourcesHintView = TextView(this).apply {
            text = "▼ DOWN: Sources • Picture • Audio"
            setTextColor(Color.parseColor("#FDE047"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        rightStatusHintView = TextView(this).apply {
            setTextColor(Color.parseColor("#E5E7EB"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
        }
        bottomHintsBar.addView(okHint)
        bottomHintsBar.addView(seekHint)
        bottomHintsBar.addView(sizeHintView)
        bottomHintsBar.addView(sourcesHintView)
        bottomHintsBar.addView(rightStatusHintView)
        root.addView(bottomHintsBar)

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
        val retryBtn = createTvPillButton("Retry") {
            errorOverlay.visibility = View.GONE
            showCenterCard("Retrying...", "", showSpinner = true)
            player?.prepare()
            player?.playWhenReady = true
        }
        val openSrcBtn = createTvPillButton("Sources") {
            errorOverlay.visibility = View.GONE
            openTvMenu(initialTab = 0)
        }
        val closeBtn = createTvPillButton("Close") { finishPlayerCleanly() }
        val errRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, 0)
            addView(retryBtn)
            addView(spacer(dp(12)))
            addView(openSrcBtn)
            addView(spacer(dp(12)))
            addView(closeBtn)
        }
        errorOverlay.addView(errorMessageView)
        errorOverlay.addView(errRow)
        root.addView(errorOverlay)
    }

    private fun buildTvSourcesAndSettingsMenu(root: FrameLayout) {
        tvMenuOverlay = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#E81B2638"))
            visibility = View.GONE
            isClickable = true
            isFocusable = false
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(18), dp(24), dp(18))
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        val topTabsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        tabSourcesBtn = createTvTopTabButton("Sources (0)") { switchMenuTab(0) }
        tabPictureBtn = createTvTopTabButton("Picture & Size") { switchMenuTab(1) }
        tabAudioBtn = createTvTopTabButton("Audio") { switchMenuTab(2) }
        tabSubtitlesBtn = createTvTopTabButton("Subtitles") { switchMenuTab(3) }

        val tabSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
        }

        closeMenuBtn = Button(this).apply {
            text = "✕  Close"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            isFocusable = true
            isFocusableInTouchMode = false
            setPadding(dp(16), dp(8), dp(16), dp(8))
            background = createTvTabBackground(isActive = false, isClose = true)
            setOnClickListener { closeTvMenu() }
        }

        topTabsRow.addView(tabSourcesBtn)
        topTabsRow.addView(spacer(dp(10)))
        topTabsRow.addView(tabPictureBtn)
        topTabsRow.addView(spacer(dp(10)))
        topTabsRow.addView(tabAudioBtn)
        topTabsRow.addView(spacer(dp(10)))
        topTabsRow.addView(tabSubtitlesBtn)
        topTabsRow.addView(tabSpacer)
        topTabsRow.addView(closeMenuBtn)
        container.addView(topTabsRow)

        val scrollView = ScrollView(this).apply {
            setPadding(0, dp(16), 0, 0)
            isFocusable = false
            descendantFocusability = ViewGroup.FOCUS_AFTER_DESCENDANTS
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        menuContentContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            isFocusable = false
            descendantFocusability = ViewGroup.FOCUS_AFTER_DESCENDANTS
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        scrollView.addView(menuContentContainer)
        container.addView(scrollView)
        tvMenuOverlay.addView(container)
        root.addView(tvMenuOverlay)
    }

    private fun openTvMenu(initialTab: Int = 0) {
        if (!isSafeUi()) return
        handler.removeCallbacks(hideTransientUiRunnable)
        activeMenuTab = initialTab
        tvMenuOverlay.visibility = View.VISIBLE
        updateTopTabStyles()
        refreshMenuBody()
        menuContentContainer.post {
            if (!isSafeUi()) return@post
            if (menuContentContainer.childCount > 0) {
                menuContentContainer.getChildAt(0)?.requestFocus()
            } else {
                tabSourcesBtn.requestFocus()
            }
        }
    }

    private fun closeTvMenu() {
        if (!isSafeUi()) return
        tvMenuOverlay.visibility = View.GONE
        refreshTvHeaderAndHints()
        scheduleHideTransientHints()
    }

    private fun switchMenuTab(tabIndex: Int) {
        activeMenuTab = tabIndex
        updateTopTabStyles()
        refreshMenuBody()
    }

    private fun updateTopTabStyles() {
        val iptvCount = streamSources.count { isIptvSource(it) }
        tabSourcesBtn.text = "Sources (${streamSources.size} • $iptvCount IPTV)"
        val audioCount = player?.currentTracks?.groups
            ?.filter { it.type == C.TRACK_TYPE_AUDIO }
            ?.sumOf { it.length } ?: 1
        tabAudioBtn.text = "Audio ($audioCount)"
        val subCount = player?.currentTracks?.groups
            ?.filter { it.type == C.TRACK_TYPE_TEXT }
            ?.sumOf { it.length } ?: 0
        tabSubtitlesBtn.text = "Subtitles ($subCount)"

        val tabs = listOf(tabSourcesBtn, tabPictureBtn, tabAudioBtn, tabSubtitlesBtn)
        tabs.forEachIndexed { idx, btn ->
            val selected = idx == activeMenuTab
            btn.background = createTvTabBackground(isActive = selected, isClose = false)
            btn.setTextColor(if (selected) Color.parseColor("#111827") else Color.WHITE)
        }
    }

    private fun createTvTabBackground(isActive: Boolean, isClose: Boolean): StateListDrawable {
        val focused = GradientDrawable().apply {
            setColor(Color.WHITE)
            cornerRadius = dp(22).toFloat()
            setStroke(dp(3), Color.parseColor("#E50914"))
        }
        val base = GradientDrawable().apply {
            setColor(
                when {
                    isClose -> Color.parseColor("#2B3548")
                    isActive -> Color.WHITE
                    else -> Color.parseColor("#334155")
                }
            )
            cornerRadius = dp(22).toFloat()
            setStroke(
                dp(1),
                if (isActive) Color.WHITE else Color.parseColor("#64748B")
            )
        }
        return StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_focused), focused)
            addState(intArrayOf(android.R.attr.state_pressed), focused)
            addState(intArrayOf(), base)
        }
    }

    private fun createTvTopTabButton(label: String, onClick: () -> Unit): Button {
        return Button(this).apply {
            text = label
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            isFocusable = true
            isFocusableInTouchMode = false
            setPadding(dp(18), dp(9), dp(18), dp(9))
            setOnClickListener { onClick() }
        }
    }

    private fun refreshMenuBody() {
        menuContentContainer.removeAllViews()
        when (activeMenuTab) {
            0 -> renderSourcesListInMenu()
            1 -> renderPictureAndSizeInMenu()
            2 -> renderAudioTracksInMenu()
            3 -> renderSubtitlesInMenu()
        }
    }

    private fun renderSourcesListInMenu() {
        if (streamSources.isEmpty()) {
            val txt = TextView(this).apply {
                text = if (isResolvingAllSources) "Scanning Gist sources..." else "No sources available"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setPadding(dp(8), dp(20), dp(8), dp(20))
            }
            menuContentContainer.addView(txt)
            return
        }

        streamSources.forEachIndexed { index, src ->
            val isSelected = index == activeSourceIndex
            val isIptv = isIptvSource(src)

            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                isFocusable = true
                isFocusableInTouchMode = false
                isClickable = true
                setPadding(dp(16), dp(14), dp(16), dp(14))
                background = createTvCardBackground(isSelected)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = dp(10)
                }
                setOnClickListener { switchToStreamSource(index) }
                setOnKeyListener { _, keyCode, event ->
                    if (event.action == KeyEvent.ACTION_DOWN &&
                        (keyCode == KeyEvent.KEYCODE_DPAD_CENTER || keyCode == KeyEvent.KEYCODE_ENTER)
                    ) {
                        switchToStreamSource(index)
                        true
                    } else {
                        false
                    }
                }
            }

            val badge = TextView(this).apply {
                text = if (isIptv) "XTREAM" else "STREMIO"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                setPadding(dp(10), dp(6), dp(10), dp(6))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor(if (isIptv) "#0284C7" else "#4F46E5"))
                    cornerRadius = dp(6).toFloat()
                }
            }

            val infoCol = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(14), 0, dp(12), 0)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            val titleTxt = TextView(this).apply {
                text = src.title
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                typeface = Typeface.DEFAULT_BOLD
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            }
            val subTxt = TextView(this).apply {
                text = "${src.server} • ${if (src.isHindi) "Hindi" else "HD Stream"}"
                setTextColor(Color.parseColor("#CBD5E1"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                setPadding(0, dp(2), 0, 0)
            }
            infoCol.addView(titleTxt)
            infoCol.addView(subTxt)

            val checkBadge = TextView(this).apply {
                text = if (isSelected) "✓" else ""
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(dp(26), dp(26))
                if (isSelected) {
                    background = GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        setColor(Color.parseColor("#10B981"))
                    }
                }
            }

            row.addView(badge)
            row.addView(infoCol)
            row.addView(checkBadge)
            menuContentContainer.addView(row)
        }
    }

    private fun renderPictureAndSizeInMenu() {
        resizeLabels.forEachIndexed { idx, label ->
            val selected = idx == resizeIndex
            val card = createTvOptionCard(
                title = "Screen Size: $label",
                subtitle = if (selected) "Active" else "Tap / OK to apply",
                selected = selected
            ) {
                resizeIndex = idx
                applyResizeModeToPlayer(resizeModes[resizeIndex])
                refreshTvHeaderAndHints()
                refreshMenuBody()
            }
            menuContentContainer.addView(card)
        }

        PicturePreset.values().forEach { preset ->
            val selected = preset == currentPreset
            val card = createTvOptionCard(
                title = preset.displayName,
                subtitle = preset.tagline,
                selected = selected
            ) {
                currentPreset = preset
                CinemaPictureEngineState.currentPreset = preset
                prefs.edit().putString("picture_preset_pure_hw", preset.name).apply()
                refreshMenuBody()
            }
            menuContentContainer.addView(card)
        }
    }

    private fun renderAudioTracksInMenu() {
        val exo = player ?: return
        val tracks = exo.currentTracks

        val autoCard = createTvOptionCard(
            title = "Auto (Hindi Priority)",
            subtitle = "Automatic audio track selection",
            selected = true
        ) {
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
                .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                .setPreferredAudioLanguages("hi", "hin", "en")
                .build()
            closeTvMenu()
        }
        menuContentContainer.addView(autoCard)

        tracks.groups.forEach { group ->
            if (group.type == C.TRACK_TYPE_AUDIO) {
                for (i in 0 until group.length) {
                    val fmt = group.getTrackFormat(i)
                    val selected = group.isTrackSelected(i)
                    val name = formatTrackName(fmt, "Audio Track ${i + 1}")
                    val card = createTvOptionCard(
                        title = name,
                        subtitle = if (selected) "Selected" else "Select audio track",
                        selected = selected
                    ) {
                        exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                            .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
                            .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i))
                            .build()
                        closeTvMenu()
                    }
                    menuContentContainer.addView(card)
                }
            }
        }
    }

    private fun renderSubtitlesInMenu() {
        val exo = player ?: return
        val tracks = exo.currentTracks
        val isDisabled = exo.trackSelectionParameters.disabledTrackTypes.contains(C.TRACK_TYPE_TEXT)

        val offCard = createTvOptionCard(
            title = "Subtitles Off",
            subtitle = "Disable subtitles",
            selected = isDisabled
        ) {
            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                .build()
            closeTvMenu()
        }
        menuContentContainer.addView(offCard)

        tracks.groups.forEach { group ->
            if (group.type == C.TRACK_TYPE_TEXT) {
                for (i in 0 until group.length) {
                    if (group.isTrackSupported(i)) {
                        val fmt = group.getTrackFormat(i)
                        val selected = !isDisabled && group.isTrackSelected(i)
                        val name = formatTrackName(fmt, "Subtitle ${i + 1}")
                        val card = createTvOptionCard(
                            title = name,
                            subtitle = if (selected) "Active" else "Enable subtitle",
                            selected = selected
                        ) {
                            exo.trackSelectionParameters = exo.trackSelectionParameters.buildUpon()
                                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, i))
                                .build()
                            closeTvMenu()
                        }
                        menuContentContainer.addView(card)
                    }
                }
            }
        }
    }

    private fun createTvOptionCard(
        title: String,
        subtitle: String,
        selected: Boolean,
        onClick: () -> Unit
    ): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            isFocusable = true
            isFocusableInTouchMode = false
            isClickable = true
            setPadding(dp(16), dp(14), dp(16), dp(14))
            background = createTvCardBackground(selected)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(10)
            }
            setOnClickListener { onClick() }
            setOnKeyListener { _, keyCode, event ->
                if (event.action == KeyEvent.ACTION_DOWN &&
                    (keyCode == KeyEvent.KEYCODE_DPAD_CENTER || keyCode == KeyEvent.KEYCODE_ENTER)
                ) {
                    onClick()
                    true
                } else {
                    false
                }
            }
            val col = LinearLayout(this@CinemaPlayerActivity).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            val tView = TextView(this@CinemaPlayerActivity).apply {
                text = title
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                typeface = Typeface.DEFAULT_BOLD
            }
            val sView = TextView(this@CinemaPlayerActivity).apply {
                text = subtitle
                setTextColor(Color.parseColor("#CBD5E1"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            }
            col.addView(tView)
            col.addView(sView)
            addView(col)
            if (selected) {
                val mark = TextView(this@CinemaPlayerActivity).apply {
                    text = "✓"
                    setTextColor(Color.parseColor("#10B981"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    typeface = Typeface.DEFAULT_BOLD
                }
                addView(mark)
            }
        }
    }

    private fun createTvCardBackground(isSelected: Boolean): StateListDrawable {
        val focused = GradientDrawable().apply {
            setColor(Color.parseColor("#33E50914"))
            cornerRadius = dp(12).toFloat()
            setStroke(dp(3), Color.parseColor("#E50914"))
        }
        val normal = GradientDrawable().apply {
            setColor(if (isSelected) Color.parseColor("#263549") else Color.parseColor("#243042"))
            cornerRadius = dp(12).toFloat()
            setStroke(
                dp(if (isSelected) 2 else 1),
                if (isSelected) Color.parseColor("#10B981") else Color.parseColor("#475569")
            )
        }
        return StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_focused), focused)
            addState(intArrayOf(android.R.attr.state_pressed), focused)
            addState(intArrayOf(), normal)
        }
    }

    private fun switchToStreamSource(index: Int) {
        if (!isSafeUi() || index !in streamSources.indices) return
        val exo = player ?: return
        activeSourceIndex = index
        val selected = streamSources[index]
        currentActiveUrl = selected.url
        refreshTvHeaderAndHints()
        closeTvMenu()
        showCenterCard("Switching to ${selected.server}...", selected.title, showSpinner = true)

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
    }

    private fun initExoPlayer(url: String, title: String, userAgent: String, preset: PicturePreset) {
        if (!isSafeUi()) return
        trackSelector = DefaultTrackSelector(this).apply {
            setParameters(
                buildUponParameters()
                    .setMaxVideoSize(1920, 1080)
                    .setForceHighestSupportedBitrate(true)
                    .setPreferredAudioLanguages("hi", "hin", "en")
                    .setMaxAudioChannelCount(2)
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
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)
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
            override fun onAudioSessionIdChanged(audioSessionId: Int) {
                if (!isSafeUi()) return
                attachLoudnessEnhancer(audioSessionId)
            }

            override fun onPlaybackStateChanged(state: Int) {
                if (!isSafeUi()) return
                if (state == Player.STATE_BUFFERING) {
                    showCenterCard("Buffering stream...", "", showSpinner = true)
                } else if (state == Player.STATE_READY) {
                    centerStatusCard.visibility = View.GONE
                    applyResizeModeToPlayer(resizeModes[resizeIndex])
                    if (loudnessEnhancer == null) {
                        attachLoudnessEnhancer(exo.audioSessionId)
                    }
                    scheduleHideTransientHints()
                }
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                if (!isSafeUi()) return
                applyResizeModeToPlayer(resizeModes[resizeIndex])
            }

            override fun onPlayerError(error: PlaybackException) {
                if (!isSafeUi()) return
                centerStatusCard.visibility = View.GONE
                if (activeSourceIndex + 1 < streamSources.size) {
                    switchToStreamSource(activeSourceIndex + 1)
                } else {
                    showError("Playback Error: ${error.localizedMessage ?: error.errorCodeName}")
                }
            }
        })

        playerView.player = exo
        applyResizeModeToPlayer(resizeModes[resizeIndex])
        exo.setMediaItem(currentMediaItem)
        exo.prepare()
        exo.playWhenReady = true
        player = exo
        attachLoudnessEnhancer(exo.audioSessionId)
    }

    private fun formatTrackName(fmt: Format, fallback: String): String {
        val lang = fmt.language
            ?.takeIf { it.isNotBlank() && it != "und" }
            ?.let { Locale(it).displayLanguage }
            ?.takeIf { it.isNotBlank() }
        return listOfNotNull(fmt.label, lang).distinct().joinToString(" • ").ifBlank { fallback }
    }

    private fun setupTvTouchGestures(view: View) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)

        var startX = 0f
        var startY = 0f
        var draggingVertical = false
        var startEffectiveVol = 100

        val detector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                if (tvMenuOverlay.visibility == View.VISIBLE) {
                    closeTvMenu()
                } else {
                    openTvMenu(initialTab = 0)
                }
                return true
            }
        })

        view.setOnTouchListener { v, event ->
            detector.onTouchEvent(event)
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = event.x
                    startY = event.y
                    draggingVertical = false
                    val sysPercent = (audioManager.getStreamVolume(AudioManager.STREAM_MUSIC) * 100) / maxVol
                    startEffectiveVol = if (sysPercent >= 100) currentBoostPercent else sysPercent
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.x - startX
                    val dy = startY - event.y
                    if (!draggingVertical && abs(dy) > dp(18) && abs(dy) > abs(dx)) {
                        draggingVertical = true
                    }
                    if (draggingVertical && v.height > 0 && startX >= v.width / 2f) {
                        val deltaRatio = dy / (v.height * 0.65f)
                        val targetPercent = (startEffectiveVol + (deltaRatio * 200f).toInt()).coerceIn(0, 200)
                        if (targetPercent <= 100) {
                            val sysStep = ((targetPercent * maxVol) / 100).coerceIn(0, maxVol)
                            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, sysStep, 0)
                            applyAudioBoostPercent(100, showToast = false)
                        } else {
                            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxVol, 0)
                            applyAudioBoostPercent(targetPercent, showToast = false)
                        }
                    }
                }
            }
            true
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (tvMenuOverlay.visibility == View.VISIBLE) {
            if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
                closeTvMenu()
                return true
            }
            return super.onKeyDown(keyCode, event)
        }

        return when (keyCode) {
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                openTvMenu(initialTab = 0)
                true
            }
            KeyEvent.KEYCODE_DPAD_UP -> {
                resizeIndex = (resizeIndex + 1) % resizeModes.size
                applyResizeModeToPlayer(resizeModes[resizeIndex])
                refreshTvHeaderAndHints()
                showCenterCard("Screen Size: ${resizeLabels[resizeIndex]}", "Press ▼ DOWN for menu", showSpinner = false)
                scheduleHideTransientHints()
                true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                seekBy(-seekStepMs)
                true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                seekBy(seekStepMs)
                true
            }
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                togglePlayPause()
                true
            }
            KeyEvent.KEYCODE_BACK -> {
                finishPlayerCleanly()
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }

    private fun togglePlayPause() {
        val exo = player ?: return
        if (exo.isPlaying) {
            exo.pause()
            showCenterCard("Paused", "Press OK to play • ▼ DOWN for Sources", showSpinner = false)
        } else {
            exo.play()
            showCenterCard("Playing", "", showSpinner = false)
            scheduleHideTransientHints()
        }
    }

    private fun seekBy(deltaMs: Long) {
        val exo = player ?: return
        val dur = exo.duration.takeIf { it > 0 } ?: Long.MAX_VALUE
        val target = (exo.currentPosition + deltaMs).coerceIn(0L, dur)
        exo.seekTo(target)
        showCenterCard(
            if (deltaMs < 0) "◄ -${seekStepSec}s (${formatTime(target)})" else "+${seekStepSec}s ► (${formatTime(target)})",
            "",
            showSpinner = false
        )
        scheduleHideTransientHints()
    }

    private fun showError(msg: String) {
        if (!isSafeUi()) return
        errorMessageView.text = msg
        errorOverlay.visibility = View.VISIBLE
    }

    private fun createTvPillButton(label: String, onClick: () -> Unit): Button {
        return Button(this).apply {
            text = label
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            isFocusable = true
            isFocusableInTouchMode = false
            setPadding(dp(16), dp(8), dp(16), dp(8))
            background = createTvTabBackground(isActive = false, isClose = false)
            setOnClickListener { onClick() }
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
        try { player?.pause() } catch (_: Throwable) {}
    }

    override fun onDestroy() {
        isActivityDestroyed = true
        handler.removeCallbacksAndMessages(null)
        releaseLoudnessEnhancer()
        try {
            playerView.player = null
            player?.stop()
            player?.release()
            player = null
        } catch (_: Throwable) {}
        super.onDestroy()
    }
}
