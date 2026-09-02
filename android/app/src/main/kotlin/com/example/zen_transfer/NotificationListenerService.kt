package com.example.zen_transfer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.os.Build

/**
 * Simple in-process event bus for notification events.
 * Avoids holding EventChannel.EventSink references across lifecycle boundaries.
 */
object NotificationBus {
    private val listeners = mutableListOf<(String, String?, String?) -> Unit>()

    fun emit(pkg: String, title: String?, text: String?) {
        for (listener in listeners) {
            listener(pkg, title, text)
        }
    }

    fun add(listener: (String, String?, String?) -> Unit) {
        if (!listeners.contains(listener)) {
            listeners.add(listener)
        }
    }

    fun remove(listener: (String, String?, String?) -> Unit) {
        listeners.remove(listener)
    }
}

/**
 * Listens for all device notifications and forwards them through [NotificationBus].
 * Runs as a foreground service on API 34+ to survive background restrictions.
 */
class ZenNotificationListener : NotificationListenerService() {

    companion object {
        private const val CHANNEL_ID = "zen_notification_listener"
        private const val NOTIFICATION_ID = 1
    }

    override fun onListenerConnected() {
        super.onListenerConnected()

        // Push active (already-posted) notifications through the bus
        try {
            for (sbn in activeNotifications) {
                processNotification(sbn)
            }
        } catch (_: SecurityException) {
            // Listener may not have full access yet
        }

        // Start foreground on API 34+ to avoid being killed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, buildForegroundNotification())
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        processNotification(sbn)
    }

    private fun processNotification(sbn: StatusBarNotification) {
        val pkg = sbn.packageName

        // Skip our own notifications
        if (pkg == packageName) return

        // Skip group summary notifications
        val flags = sbn.notification.flags
        if ((flags and Notification.FLAG_GROUP_SUMMARY) != 0) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(android.app.Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(android.app.Notification.EXTRA_TEXT)?.toString()

        NotificationBus.emit(pkg, title, text)
    }

    private fun buildForegroundNotification(): Notification {
        // Create the channel (idempotent on API 26+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Notification Mirroring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps notification mirroring service alive"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("ZenTransfer")
                .setContentText("Mirroring notifications to PC")
                .setSmallIcon(android.R.drawable.ic_popup_sync)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("ZenTransfer")
                .setContentText("Mirroring notifications to PC")
                .setSmallIcon(android.R.drawable.ic_popup_sync)
                .setOngoing(true)
                .build()
        }
    }
}
