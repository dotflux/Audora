package com.example.audora

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.embedding.engine.FlutterEngine
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.plugin.common.MethodChannel
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.support.v4.media.MediaMetadataCompat
import androidx.palette.graphics.Palette
import androidx.media.session.MediaButtonReceiver
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : AudioServiceActivity() {
    private val CHANNEL_ID = "audora_media_channel"
    private val METHOD_CHANNEL = "audora/notification"
    private val NOTIFICATION_ID = 1


    private val ACTION_PREV = "com.example.audora.ACTION_PREV"
    private val ACTION_TOGGLE = "com.example.audora.ACTION_TOGGLE"
    private val ACTION_NEXT = "com.example.audora.ACTION_NEXT"
    private val ACTION_SEEK = "com.example.audora.ACTION_SEEK"
    private val ACTION_BEST_PART = "com.example.audora.ACTION_BEST_PART"

    private var notificationManager: NotificationManager? = null
    private lateinit var methodChannel: MethodChannel
    private lateinit var mediaSession: MediaSessionCompat
    private val executor = Executors.newSingleThreadExecutor()

 
    private var currentBuilder: NotificationCompat.Builder? = null
    private var currentBitmap: Bitmap? = null
    private var currentArtworkUrl: String? = null
    private var currentAccentColor: Int? = null


    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action ?: return
            try {
                val extras = if (intent.hasExtra("positionMs")) {
                    mapOf("positionMs" to intent.getLongExtra("positionMs", 0L))
                } else null
                methodChannel.invokeMethod("onNotificationAction", mapOf(
                    "action" to action,
                    "extras" to (extras ?: emptyMap<String, Any>())
                ))
            } catch (t: Throwable) {
                t.printStackTrace()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Audora Playback",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            channel.setShowBadge(false)
            notificationManager?.createNotificationChannel(channel)
        }

        mediaSession = MediaSessionCompat(this, "AudoraMediaSession")
        mediaSession.isActive = true

        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() {
                super.onPlay()
                try {
                    methodChannel.invokeMethod("onNotificationAction", mapOf("action" to ACTION_TOGGLE))
                } catch (t: Throwable) { t.printStackTrace() }
            }

            override fun onPause() {
                super.onPause()
                try {
                    methodChannel.invokeMethod("onNotificationAction", mapOf("action" to ACTION_TOGGLE))
                } catch (t: Throwable) { t.printStackTrace() }
            }

            override fun onSkipToNext() {
                super.onSkipToNext()
                try {
                    methodChannel.invokeMethod("onNotificationAction", mapOf("action" to ACTION_NEXT))
                } catch (t: Throwable) { t.printStackTrace() }
            }

            override fun onSkipToPrevious() {
                super.onSkipToPrevious()
                try {
                    methodChannel.invokeMethod("onNotificationAction", mapOf("action" to ACTION_PREV))
                } catch (t: Throwable) { t.printStackTrace() }
            }

            override fun onSeekTo(pos: Long) {
                super.onSeekTo(pos)
                try {
                    methodChannel.invokeMethod("onNotificationAction", mapOf(
                        "action" to ACTION_SEEK,
                        "extras" to mapOf("positionMs" to pos)
                    ))
                } catch (t: Throwable) { t.printStackTrace() }
            }
        })

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title") as? String ?: "Playing"
                    val artist = args?.get("artist") as? String ?: ""
                    val artworkUrl = args?.get("artworkUrl") as? String
                    val isPlaying = args?.get("isPlaying") as? Boolean ?: false
                    val positionMs = (args?.get("positionMs") as? Number)?.toLong()
                    val durationMs = (args?.get("durationMs") as? Number)?.toLong()
                    val hasBestPart = args?.get("hasBestPart") as? Boolean ?: false

                    showNotification(title, artist, isPlaying, artworkUrl, positionMs, durationMs, hasBestPart)
                    result.success(null)
                }
                "hide" -> {
                    notificationManager?.cancel(NOTIFICATION_ID)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        val filter = IntentFilter().apply {
            addAction(ACTION_PREV)
            addAction(ACTION_TOGGLE)
            addAction(ACTION_NEXT)
            addAction(ACTION_BEST_PART)
        }
        registerReceiver(actionReceiver, filter)
    }

    private fun mediaPendingIntentFor(action: String): PendingIntent {
        val intent = Intent(action).apply {
            setPackage(packageName)
        }
        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(this, action.hashCode(), intent, flag)
    }

    private fun createContentIntent(): PendingIntent {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, javaClass)
        launch.action = Intent.ACTION_MAIN
        launch.addCategory(Intent.CATEGORY_LAUNCHER)
        return PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun updateMediaSessionMetadata(title: String, artist: String, durationMs: Long?) {
        val metaBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
        if (durationMs != null) metaBuilder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
        currentBitmap?.let { metaBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it) }
        mediaSession.setMetadata(metaBuilder.build())
    }

    private fun updateMediaSessionPlaybackState(isPlaying: Boolean, positionMs: Long?) {
        val actions = (PlaybackStateCompat.ACTION_PLAY
                or PlaybackStateCompat.ACTION_PAUSE
                or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
                or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
                or PlaybackStateCompat.ACTION_SEEK_TO)
        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val pos = positionMs ?: 0L

        val pb = PlaybackStateCompat.Builder()
            .setActions(actions)
            .setState(state, pos, 1.0f)
            .setActiveQueueItemId(0L)
            .build()
        mediaSession.setPlaybackState(pb)
    }

    private fun showNotification(
        title: String,
        artist: String,
        isPlaying: Boolean,
        artworkUrl: String?,
        positionMs: Long?,
        durationMs: Long?,
        hasBestPart: Boolean = false
    ) {
        updateMediaSessionMetadata(title, artist, durationMs)
        updateMediaSessionPlaybackState(isPlaying, positionMs)

        val compactViewIndices = intArrayOf(0,2,3)

        if (!artworkUrl.isNullOrEmpty() && artworkUrl != currentArtworkUrl) {
            currentBitmap = null
            currentAccentColor = null
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID).apply {
            setContentIntent(createContentIntent())
            setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            setOnlyAlertOnce(true)
            setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(*compactViewIndices)
                    .setShowCancelButton(false)
            )
            currentBitmap?.let { setLargeIcon(it) }
            priority = NotificationCompat.PRIORITY_DEFAULT
        }

        builder.setContentTitle(title)
            .setContentText(artist)
            .setSmallIcon(getAppSmallIconResource())
            .setOngoing(isPlaying)

        try {
            builder.mActions.clear()
        } catch (_: Throwable) {
        }

        builder.addAction(
            NotificationCompat.Action(
                android.R.drawable.ic_menu_rotate,
                "Best Part",
                mediaPendingIntentFor(ACTION_BEST_PART)
            )
        )

        builder.addAction(
            NotificationCompat.Action(
                android.R.drawable.ic_media_previous,
                "Previous",
                mediaPendingIntentFor(ACTION_PREV)
            )
        )

        val toggleIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        builder.addAction(
            NotificationCompat.Action(
                toggleIcon,
                if (isPlaying) "Pause" else "Play",
                mediaPendingIntentFor(ACTION_TOGGLE)
            )
        )

        builder.addAction(
            NotificationCompat.Action(
                android.R.drawable.ic_media_next,
                "Next",
                mediaPendingIntentFor(ACTION_NEXT)
            )
        )

        if (positionMs != null && durationMs != null && durationMs > 0) {
            val max = durationMs.toInt().coerceAtLeast(1)
            val progress = positionMs.coerceAtMost(durationMs).toInt()
            builder.setProgress(max, progress, false)

            val seekIntent = Intent(ACTION_SEEK).apply {
                setPackage(packageName)
                putExtra("positionMs", positionMs)
            }
            val seekPendingIntent = PendingIntent.getBroadcast(
                this,
                999,
                seekIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )
        } else {
            builder.setProgress(0, 0, false)
        }

        currentAccentColor?.let { color ->
            builder.setColor(color)
        }

        currentBuilder = builder
        notificationManager?.notify(NOTIFICATION_ID, builder.build())

        if (!artworkUrl.isNullOrEmpty() && artworkUrl != currentArtworkUrl) {
            currentArtworkUrl = artworkUrl
            executor.submit {
                try {
                    val bmp = fetchBitmapFromURL(artworkUrl)
                    if (bmp != null) {
                        val composite = overlayAppIconOnArtwork(bmp)

                        val palette = Palette.from(bmp).generate()
                        val swatch = palette.vibrantSwatch ?: palette.mutedSwatch ?: palette.dominantSwatch
                        val dominant = swatch?.rgb ?: 0xFF212121.toInt()

                        synchronized(this) {
                            currentBitmap = composite
                            currentAccentColor = dominant
                        }

                        try {
                            val updatedBuilder = NotificationCompat.Builder(this@MainActivity, CHANNEL_ID).apply {
                                setContentIntent(createContentIntent())
                                setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                                setOnlyAlertOnce(true)
                                setStyle(
                                    MediaStyle()
                                        .setMediaSession(mediaSession.sessionToken)
                                        .setShowActionsInCompactView(*compactViewIndices)
                                        .setShowCancelButton(false)
                                )
                                setLargeIcon(composite)
                                setColor(dominant)
                                priority = NotificationCompat.PRIORITY_DEFAULT
                            }
                            updatedBuilder.setContentTitle(title)
                                .setContentText(artist)
                                .setSmallIcon(getAppSmallIconResource())
                                .setOngoing(isPlaying)

                            try {
                                updatedBuilder.mActions.clear()
                            } catch (_: Throwable) {}

                            updatedBuilder.addAction(
                                NotificationCompat.Action(
                                    android.R.drawable.ic_menu_rotate,
                                    "Best Part",
                                    mediaPendingIntentFor(ACTION_BEST_PART)
                                )
                            )
                            updatedBuilder.addAction(
                                NotificationCompat.Action(
                                    android.R.drawable.ic_media_previous,
                                    "Previous",
                                    mediaPendingIntentFor(ACTION_PREV)
                                )
                            )
                            val toggleIcon2 = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
                            updatedBuilder.addAction(
                                NotificationCompat.Action(
                                    toggleIcon2,
                                    if (isPlaying) "Pause" else "Play",
                                    mediaPendingIntentFor(ACTION_TOGGLE)
                                )
                            )
                            updatedBuilder.addAction(
                                NotificationCompat.Action(
                                    android.R.drawable.ic_media_next,
                                    "Next",
                                    mediaPendingIntentFor(ACTION_NEXT)
                                )
                            )

                            if (positionMs != null && durationMs != null && durationMs > 0) {
                                val max = durationMs.toInt().coerceAtLeast(1)
                                val progress = positionMs.coerceAtMost(durationMs).toInt()
                                updatedBuilder.setProgress(max, progress, false)
                            } else {
                                updatedBuilder.setProgress(0, 0, false)
                            }

                            currentBuilder = updatedBuilder
                            notificationManager?.notify(NOTIFICATION_ID, updatedBuilder.build())
                            updateMediaSessionMetadata(title, artist, durationMs)
                        } catch (t: Throwable) {
                            t.printStackTrace()
                        }
                    }
                } catch (t: Throwable) {
                    t.printStackTrace()
                }
            }
        }
    }

    private fun fetchBitmapFromURL(src: String): Bitmap? {
        return try {
            val url = URL(src)
            val connection = url.openConnection() as HttpURLConnection
            connection.doInput = true
            connection.connectTimeout = TimeUnit.SECONDS.toMillis(8).toInt()
            connection.readTimeout = TimeUnit.SECONDS.toMillis(8).toInt()
            connection.connect()
            val input = connection.inputStream
            BitmapFactory.decodeStream(input)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun overlayAppIconOnArtwork(artwork: Bitmap): Bitmap {
        try {
            val result = artwork.copy(Bitmap.Config.ARGB_8888, true)
            val canvas = Canvas(result)
            val iconBmp = getAppLauncherBitmap()
            if (iconBmp != null) {
                val targetSize = (result.width * 0.22f).toInt()
                val scaledIcon = Bitmap.createScaledBitmap(iconBmp, targetSize, targetSize, true)
                val padding = (targetSize * 0.12f).toInt()
                val cx = result.width - scaledIcon.width / 2 - padding
                val cy = result.height - scaledIcon.height / 2 - padding
                val radius = (scaledIcon.width * 0.6f).coerceAtLeast(24f)
                val paintBg = Paint(Paint.ANTI_ALIAS_FLAG)
                paintBg.color = Color.argb(200, 0, 0, 0)
                canvas.drawCircle(cx.toFloat(), cy.toFloat(), radius, paintBg)
                val left = result.width - scaledIcon.width - padding
                val top = result.height - scaledIcon.height - padding
                canvas.drawBitmap(scaledIcon, left.toFloat(), top.toFloat(), null)
                scaledIcon.recycle()
            }
            return result
        } catch (t: Throwable) {
            t.printStackTrace()
            return artwork
        }
    }

    private fun getAppLauncherBitmap(): Bitmap? {
        return try {
            val appIconDrawable: Drawable = packageManager.getApplicationIcon(packageName)
            if (appIconDrawable is BitmapDrawable) {
                appIconDrawable.bitmap
            } else {
                val width = appIconDrawable.intrinsicWidth.takeIf { it > 0 } ?: 128
                val height = appIconDrawable.intrinsicHeight.takeIf { it > 0 } ?: 128
                val bm = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bm)
                appIconDrawable.setBounds(0, 0, canvas.width, canvas.height)
                appIconDrawable.draw(canvas)
                bm
            }
        } catch (t: Throwable) {
            t.printStackTrace()
            null
        }
    }

    private fun getAppSmallIconResource(): Int {
        return try {
            val resId = resources.getIdentifier("ic_launcher_foreground", "mipmap", packageName)
            if (resId != 0) resId else resources.getIdentifier("ic_launcher", "mipmap", packageName)
                .takeIf { it != 0 } ?: android.R.drawable.ic_media_play
        } catch (t: Throwable) {
            android.R.drawable.ic_media_play
        }
    }


    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(actionReceiver) } catch (_: Exception) {}
        executor.shutdownNow()
        try { mediaSession.release() } catch (_: Exception) {}
    }
}