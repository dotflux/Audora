package com.example.audora

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL_ID = "audora_media_channel"
    private val METHOD_CHANNEL = "audora/notification"

    private val ACTION_PREV = "com.example.audora.ACTION_PREV"
    private val ACTION_TOGGLE = "com.example.audora.ACTION_TOGGLE"
    private val ACTION_NEXT = "com.example.audora.ACTION_NEXT"
    private val ACTION_SEEK = "com.example.audora.ACTION_SEEK"
    private val ACTION_BEST_PART = "com.example.audora.ACTION_BEST_PART"

    private lateinit var methodChannel: MethodChannel
    private lateinit var mediaSession: AudoraMediaSession
    private lateinit var notificationManager: MediaNotificationManager
    private lateinit var actionReceiver: AudoraActionReceiver

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)

        mediaSession = AudoraMediaSession(this, methodChannel)
        notificationManager = MediaNotificationManager(
            this,
            mediaSession.mediaSession,
            CHANNEL_ID,
            mediaSession
        )
        actionReceiver = AudoraActionReceiver(methodChannel)

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
                    val mediaId = args?.get("mediaId") as? String

                    notificationManager.updateNotification(
                        title = title,
                        artist = artist,
                        isPlaying = isPlaying,
                        artworkUrl = artworkUrl,
                        positionMs = positionMs,
                        durationMs = durationMs,
                        hasBestPart = hasBestPart,
                        mediaId = mediaId,
                        onActionClick = { action, extras ->
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
                    )
                    result.success(null)
                }
                "hide" -> {
                    notificationManager.cancel()
                    result.success(null)
                }
                "updatePlaybackState" -> {
                    val args = call.arguments as? Map<*, *>
                    val isPlaying = args?.get("isPlaying") as? Boolean ?: false
                    val positionMs = (args?.get("positionMs") as? Number)?.toLong()
                    val durationMs = (args?.get("durationMs") as? Number)?.toLong()
                    notificationManager.updatePlaybackStateOnly(isPlaying, positionMs, durationMs)
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

        val receiverFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Context.RECEIVER_EXPORTED
        } else {
            0
        }

        registerReceiver(actionReceiver, filter, receiverFlag)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(actionReceiver)
        } catch (_: Exception) {
        }
        notificationManager.shutdown()
        mediaSession.release()
    }
}
