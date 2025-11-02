package com.example.audora

import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.support.v4.media.MediaMetadataCompat
import io.flutter.plugin.common.MethodChannel

class AudoraMediaSession(
    private val context: android.content.Context,
    private val methodChannel: MethodChannel
) {
    private val ACTION_PREV = "com.example.audora.ACTION_PREV"
    private val ACTION_TOGGLE = "com.example.audora.ACTION_TOGGLE"
    private val ACTION_NEXT = "com.example.audora.ACTION_NEXT"
    private val ACTION_SEEK = "com.example.audora.ACTION_SEEK"
    private val ACTION_BEST_PART = "com.example.audora.ACTION_BEST_PART"

    private val AUTO_ENABLED_ACTIONS = (android.support.v4.media.session.PlaybackStateCompat.ACTION_PLAY
            or android.support.v4.media.session.PlaybackStateCompat.ACTION_PAUSE
            or android.support.v4.media.session.PlaybackStateCompat.ACTION_SKIP_TO_NEXT
            or android.support.v4.media.session.PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            or android.support.v4.media.session.PlaybackStateCompat.ACTION_SEEK_TO
            or android.support.v4.media.session.PlaybackStateCompat.ACTION_PLAY_PAUSE)

    private var currentPlaybackState: PlaybackStateCompat? = null
    private var currentMetadata: MediaMetadataCompat? = null

    val mediaSession: MediaSessionCompat = MediaSessionCompat(context, "AudoraMediaSession").apply {
        isActive = true
        setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS)
        
        val initialState = PlaybackStateCompat.Builder()
            .setActions(AUTO_ENABLED_ACTIONS)
            .setState(PlaybackStateCompat.STATE_NONE, 0, 1.0f, System.currentTimeMillis())
            .build()
        setPlaybackState(initialState)
        currentPlaybackState = initialState
    }

    init {
        val sessionRef = mediaSession
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() {
                super.onPlay()
                invokeAction(ACTION_TOGGLE)
            }

            override fun onPause() {
                super.onPause()
                invokeAction(ACTION_TOGGLE)
            }

            override fun onSkipToNext() {
                super.onSkipToNext()
                invokeAction(ACTION_NEXT)
            }

            override fun onSkipToPrevious() {
                super.onSkipToPrevious()
                invokeAction(ACTION_PREV)
            }

            override fun onSeekTo(pos: Long) {
                super.onSeekTo(pos)
                
                val state = if (currentPlaybackState?.state == PlaybackStateCompat.STATE_PLAYING)
                    PlaybackStateCompat.STATE_PLAYING
                else
                    PlaybackStateCompat.STATE_PAUSED
                
                val actions = currentPlaybackState?.actions ?: AUTO_ENABLED_ACTIONS
                
                val duration = currentMetadata?.getLong(MediaMetadataCompat.METADATA_KEY_DURATION) ?: 0L
                
                val playbackState = PlaybackStateCompat.Builder()
                    .setActions(actions)
                    .setState(state, pos, currentPlaybackState?.playbackSpeed ?: 1.0f, System.currentTimeMillis())
                    .setBufferedPosition(duration)
                    .build()
                
                sessionRef.setPlaybackState(playbackState)
                currentPlaybackState = playbackState
                
                invokeAction(ACTION_SEEK, mapOf("positionMs" to pos))
            }
        })
    }

    fun updatePlaybackState(state: PlaybackStateCompat) {
        currentPlaybackState = state
    }

    fun updateMetadata(metadata: MediaMetadataCompat) {
        currentMetadata = metadata
    }

    private fun invokeAction(action: String, extras: Map<String, Any>? = null) {
        try {
            methodChannel.invokeMethod(
                "onNotificationAction",
                mapOf(
                    "action" to action,
                    "extras" to (extras ?: emptyMap<String, Any>())
                )
            )
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    fun release() {
        try {
            mediaSession.release()
        } catch (_: Exception) {
        }
    }
}

