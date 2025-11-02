package com.example.audora

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.support.v4.media.MediaMetadataCompat
import androidx.palette.graphics.Palette
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MediaNotificationManager(
    private val context: Context,
    private val mediaSession: MediaSessionCompat,
    private val notificationChannelId: String,
    private val audoraMediaSession: AudoraMediaSession? = null
) {
    private val NOTIFICATION_ID = 1
    private val MAX_COMPACT_ACTIONS = 3

    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val executor = Executors.newSingleThreadExecutor()

    private var currentBitmap: Bitmap? = null
    private var currentArtworkUrl: String? = null
    private var currentAccentColor: Int? = null

    private var compactActionIndices: IntArray? = null

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "Audora Playback",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            channel.setShowBadge(false)
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun updatePlaybackStateOnly(
        isPlaying: Boolean,
        positionMs: Long?,
        durationMs: Long?
    ) {
        if (durationMs != null && durationMs > 0) {
            currentDurationMs = durationMs
        }
        updateMediaSessionPlaybackState(isPlaying, positionMs, durationMs)
    }

    fun updateNotification(
        title: String,
        artist: String,
        isPlaying: Boolean,
        artworkUrl: String?,
        positionMs: Long?,
        durationMs: Long?,
        hasBestPart: Boolean,
        mediaId: String? = null,
        onActionClick: (String, Map<String, Any>?) -> Unit
    ) {
        updateMediaSessionMetadata(title, artist, durationMs, mediaId)
        updateMediaSessionPlaybackState(isPlaying, positionMs, durationMs)

        val actions = buildActions(isPlaying, hasBestPart, onActionClick)
        compactActionIndices = calculateCompactIndices(hasBestPart)

        val builder = buildNotificationBuilder(title, artist, isPlaying, actions)
        setProgress(positionMs, durationMs, builder)

        notificationManager.notify(NOTIFICATION_ID, builder.build())

        if (!artworkUrl.isNullOrEmpty() && artworkUrl != currentArtworkUrl) {
            loadArtworkAsync(artworkUrl, title, artist, isPlaying, positionMs, durationMs, hasBestPart, onActionClick)
        }
    }

    private fun buildActions(
        isPlaying: Boolean,
        hasBestPart: Boolean,
        onActionClick: (String, Map<String, Any>?) -> Unit
    ): List<NotificationCompat.Action> {
        val actions = mutableListOf<NotificationCompat.Action>()

        if (hasBestPart) {
            val bestPartIcon = try {
                context.resources.getIdentifier("ic_menu_compass", "drawable", "android")
                    .takeIf { it != 0 } ?: android.R.drawable.ic_menu_compass
            } catch (_: Throwable) {
                android.R.drawable.ic_menu_revert
            }
            
            actions.add(
                NotificationCompat.Action(
                    bestPartIcon,
                    "Best Part",
                    createPendingIntent("com.example.audora.ACTION_BEST_PART", onActionClick)
                )
            )
        }

        actions.add(
            NotificationCompat.Action(
                android.R.drawable.ic_media_previous,
                "Previous",
                createPendingIntent("com.example.audora.ACTION_PREV", onActionClick)
            )
        )

        val toggleIcon = if (isPlaying)
            android.R.drawable.ic_media_pause
        else
            android.R.drawable.ic_media_play

        actions.add(
            NotificationCompat.Action(
                toggleIcon,
                if (isPlaying) "Pause" else "Play",
                createPendingIntent("com.example.audora.ACTION_TOGGLE", onActionClick)
            )
        )

        actions.add(
            NotificationCompat.Action(
                android.R.drawable.ic_media_next,
                "Next",
                createPendingIntent("com.example.audora.ACTION_NEXT", onActionClick)
            )
        )

        return actions
    }

    private fun calculateCompactIndices(hasBestPart: Boolean): IntArray {
        return if (hasBestPart) {
            intArrayOf(0, 2, 3)
        } else {
            intArrayOf(1, 2, 3)
        }
    }

    private fun createPendingIntent(
        action: String,
        onActionClick: (String, Map<String, Any>?) -> Unit
    ): PendingIntent {
        val intent = Intent(action).apply {
            setPackage(context.packageName)
        }

        val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        return PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            flag
        )
    }

    private fun createContentIntent(): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        launch.action = Intent.ACTION_MAIN
        launch.addCategory(Intent.CATEGORY_LAUNCHER)
        return PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun buildNotificationBuilder(
        title: String,
        artist: String,
        isPlaying: Boolean,
        actions: List<NotificationCompat.Action>
    ): NotificationCompat.Builder {
        val builder = NotificationCompat.Builder(context, notificationChannelId).apply {
            setContentIntent(createContentIntent())
            setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            setOnlyAlertOnce(true)
            setShowWhen(false)
            currentBitmap?.let { setLargeIcon(it) }
            priority = NotificationCompat.PRIORITY_DEFAULT
            setContentTitle(title)
            setContentText(artist)
            setSmallIcon(getAppSmallIconResource())
            setOngoing(isPlaying)
        }

        try {
            builder.mActions.clear()
        } catch (_: Throwable) {
        }

        for (action in actions) {
            builder.addAction(action)
        }

        val mediaStyle = MediaStyle()
            .setMediaSession(mediaSession.sessionToken)
            .setShowCancelButton(false)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            compactActionIndices?.let {
                mediaStyle.setShowActionsInCompactView(*it)
            }
        }

        builder.setStyle(mediaStyle)

        currentAccentColor?.let { color ->
            builder.setColor(color)
        }

        return builder
    }

    fun setProgress(positionMs: Long?, durationMs: Long?, builder: NotificationCompat.Builder) {
        if (durationMs != null && durationMs > 0) {
            currentDurationMs = durationMs
        }
        val effectiveDuration = currentDurationMs
        if (positionMs != null && effectiveDuration != null && effectiveDuration > 0) {
            val max = effectiveDuration.toInt().coerceAtLeast(1)
            val progress = positionMs.coerceAtMost(effectiveDuration).toInt()
            builder.setProgress(max, progress, false)
        } else {
            builder.setProgress(0, 0, false)
        }
    }

    private var currentMediaId: String? = null
    private var currentDurationMs: Long? = null

    private fun updateMediaSessionMetadata(title: String, artist: String, durationMs: Long?, mediaId: String? = null) {
        if (durationMs != null && durationMs > 0) {
            currentDurationMs = durationMs
        }

        val metaBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)

        if (mediaId != null) {
            metaBuilder.putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, mediaId)
            currentMediaId = mediaId
        } else if (currentMediaId != null) {
            metaBuilder.putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, currentMediaId)
        }

        if (currentDurationMs != null && currentDurationMs!! > 0) {
            metaBuilder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentDurationMs!!)
        }

        currentBitmap?.let {
            metaBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it)
        }

        val metadata = metaBuilder.build()
        mediaSession.setMetadata(metadata)
        audoraMediaSession?.updateMetadata(metadata)
    }

    private fun updateMediaSessionPlaybackState(
        isPlaying: Boolean,
        positionMs: Long?,
        durationMs: Long?
    ) {
        if (durationMs != null && durationMs > 0) {
            currentDurationMs = durationMs
        }

        val actions = (PlaybackStateCompat.ACTION_PLAY
                or PlaybackStateCompat.ACTION_PAUSE
                or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
                or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
                or PlaybackStateCompat.ACTION_SEEK_TO)

        val state = if (isPlaying)
            PlaybackStateCompat.STATE_PLAYING
        else
            PlaybackStateCompat.STATE_PAUSED

        val pos = positionMs ?: 0L
        val duration = currentDurationMs ?: 0L

        val updateTime = System.currentTimeMillis()

        val pb = PlaybackStateCompat.Builder()
            .setActions(actions)
            .setState(state, pos, 1.0f, updateTime)
            .setBufferedPosition(duration)
            .setActiveQueueItemId(0L)
        
        if (currentMediaId != null) {
            val extras = android.os.Bundle().apply {
                putString("android.media.playback.EXTRAS_KEY_MEDIA_ID", currentMediaId)
            }
            pb.setExtras(extras)
        }
        
        val playbackState = pb.build()
        mediaSession.setPlaybackState(playbackState)
        
        audoraMediaSession?.updatePlaybackState(playbackState)
    }

    private fun loadArtworkAsync(
        artworkUrl: String,
        title: String,
        artist: String,
        isPlaying: Boolean,
        positionMs: Long?,
        durationMs: Long?,
        hasBestPart: Boolean,
        onActionClick: (String, Map<String, Any>?) -> Unit
    ) {
        currentArtworkUrl = artworkUrl

        executor.submit {
            try {
                val bmp = fetchBitmapFromURL(artworkUrl)
                if (bmp != null) {
                    val composite = overlayAppIconOnArtwork(bmp)
                    val palette = Palette.from(bmp).generate()
                    val swatch = palette.vibrantSwatch
                        ?: palette.mutedSwatch
                        ?: palette.dominantSwatch
                    val dominant = swatch?.rgb ?: 0xFF212121.toInt()

                    synchronized(this) {
                        currentBitmap = composite
                        currentAccentColor = dominant
                    }

                    if (durationMs != null && durationMs > 0) {
                        currentDurationMs = durationMs
                    }

                    val actions = buildActions(isPlaying, hasBestPart, onActionClick)
                    val builder = buildNotificationBuilder(title, artist, isPlaying, actions)
                    setProgress(positionMs, durationMs, builder)

                    notificationManager.notify(NOTIFICATION_ID, builder.build())
                    updateMediaSessionMetadata(title, artist, durationMs)
                }
            } catch (t: Throwable) {
                t.printStackTrace()
            }
        }
    }

    private fun fetchBitmapFromURL(src: String): Bitmap? {
        return try {
            val uri = android.net.Uri.parse(src)
            if (uri.scheme == "file") {
                val filePath = uri.path
                val file = java.io.File(filePath)
                if (file.exists()) {
                    BitmapFactory.decodeFile(file.absolutePath)
                } else {
                    null
                }
            } else {
                val url = URL(src)
                val connection = url.openConnection() as HttpURLConnection
                connection.doInput = true
                connection.connectTimeout = TimeUnit.SECONDS.toMillis(8).toInt()
                connection.readTimeout = TimeUnit.SECONDS.toMillis(8).toInt()
                connection.connect()
                val input = connection.inputStream
                BitmapFactory.decodeStream(input)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun overlayAppIconOnArtwork(artwork: Bitmap): Bitmap {
        return try {
            val result = artwork.copy(Bitmap.Config.ARGB_8888, true)
            val canvas = android.graphics.Canvas(result)
            val iconBmp = getAppLauncherBitmap()
            if (iconBmp != null) {
                val targetSize = (result.width * 0.22f).toInt()
                val scaledIcon = Bitmap.createScaledBitmap(iconBmp, targetSize, targetSize, true)
                val padding = (targetSize * 0.12f).toInt()
                val cx = result.width - scaledIcon.width / 2 - padding
                val cy = result.height - scaledIcon.height / 2 - padding
                val radius = (scaledIcon.width * 0.6f).coerceAtLeast(24f)
                val paintBg = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
                paintBg.color = android.graphics.Color.argb(200, 0, 0, 0)
                canvas.drawCircle(cx.toFloat(), cy.toFloat(), radius, paintBg)
                val left = result.width - scaledIcon.width - padding
                val top = result.height - scaledIcon.height - padding
                canvas.drawBitmap(scaledIcon, left.toFloat(), top.toFloat(), null)
                scaledIcon.recycle()
            }
            result
        } catch (t: Throwable) {
            t.printStackTrace()
            artwork
        }
    }

    private fun getAppLauncherBitmap(): Bitmap? {
        return try {
            val appIconDrawable = context.packageManager.getApplicationIcon(context.packageName)
            if (appIconDrawable is android.graphics.drawable.BitmapDrawable) {
                appIconDrawable.bitmap
            } else {
                val width = appIconDrawable.intrinsicWidth.takeIf { it > 0 } ?: 128
                val height = appIconDrawable.intrinsicHeight.takeIf { it > 0 } ?: 128
                val bm = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(bm)
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
            val resId = context.resources.getIdentifier(
                "ic_launcher_foreground",
                "mipmap",
                context.packageName
            )
            if (resId != 0) {
                resId
            } else {
                context.resources.getIdentifier(
                    "ic_launcher",
                    "mipmap",
                    context.packageName
                ).takeIf { it != 0 } ?: android.R.drawable.ic_media_play
            }
        } catch (t: Throwable) {
            android.R.drawable.ic_media_play
        }
    }

    fun cancel() {
        notificationManager.cancel(NOTIFICATION_ID)
    }

    fun shutdown() {
        executor.shutdownNow()
    }
}

