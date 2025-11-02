package com.example.audora

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

class AudoraActionReceiver(
    private val methodChannel: MethodChannel
) : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        try {
            val extras = if (intent.hasExtra("positionMs")) {
                mapOf("positionMs" to intent.getLongExtra("positionMs", 0L))
            } else {
                null
            }

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
}

