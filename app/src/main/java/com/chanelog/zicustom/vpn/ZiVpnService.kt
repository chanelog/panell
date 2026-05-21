package com.chanelog.zicustom.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.chanelog.zicustom.R
import com.chanelog.zicustom.core.ZiCore
import com.chanelog.zicustom.data.VpnConfig
import com.chanelog.zicustom.ui.MainActivity

class ZiVpnService : VpnService() {

    private var tun: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTunnel("user requested stop")
                return START_NOT_STICKY
            }
            else -> {
                val cfg = VpnConfig.load(this)
                if (cfg.host.isBlank() || cfg.password.isBlank()) {
                    broadcast(STATE_ERROR, "Konfigurasi belum lengkap")
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForeground(NOTIF_ID, buildNotification(getString(R.string.notif_running)))
                startTunnel(cfg)
            }
        }
        return START_STICKY
    }

    private fun startTunnel(cfg: VpnConfig) {
        broadcast(STATE_CONNECTING, "Connecting to ${cfg.host}:${cfg.port}")
        try {
            val builder = Builder()
                .setSession(getString(R.string.app_name))
                .setMtu(cfg.mtu)
                .addAddress("10.10.10.2", 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")

            // Bypass our own app traffic so the tunnel transport can dial the server.
            try { builder.addDisallowedApplication(packageName) } catch (_: Throwable) {}

            tun = builder.establish()
            val fd = tun?.fd ?: run {
                broadcast(STATE_ERROR, "Gagal establish() — VPN permission?")
                stopSelf()
                return
            }

            val ok = ZiCore.start(cfg, fd)
            if (!ok) {
                broadcast(STATE_ERROR, "Core gagal start")
                stopTunnel("core start failed")
                return
            }
            broadcast(STATE_CONNECTED, "Tunnel aktif (mode: ${if (isStub()) "stub" else "native"})")
        } catch (t: Throwable) {
            Log.e(TAG, "startTunnel failed", t)
            broadcast(STATE_ERROR, t.message ?: "unknown error")
            stopTunnel("exception")
        }
    }

    private fun stopTunnel(reason: String) {
        Log.i(TAG, "stopTunnel: $reason")
        ZiCore.stop()
        try { tun?.close() } catch (_: Throwable) {}
        tun = null
        broadcast(STATE_DISCONNECTED, "Disconnected ($reason)")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopTunnel("service destroyed")
        super.onDestroy()
    }

    private fun isStub(): Boolean = try {
        Class.forName("dev.zivpn.Core"); false
    } catch (_: ClassNotFoundException) { true }

    private fun broadcast(state: String, message: String) {
        val i = Intent(BROADCAST_STATE).apply {
            setPackage(packageName)
            putExtra(EXTRA_STATE, state)
            putExtra(EXTRA_MESSAGE, message)
        }
        sendBroadcast(i)
    }

    private fun buildNotification(text: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.notif_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = getString(R.string.notif_channel_desc) }
            nm.createNotificationChannel(ch)
        }
        val tap = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_status_dot)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(tap)
            .build()
    }

    companion object {
        private const val TAG = "ZiVpnService"
        const val ACTION_START = "com.chanelog.zicustom.action.START"
        const val ACTION_STOP = "com.chanelog.zicustom.action.STOP"
        const val BROADCAST_STATE = "com.chanelog.zicustom.STATE"
        const val EXTRA_STATE = "state"
        const val EXTRA_MESSAGE = "message"

        const val STATE_CONNECTING = "connecting"
        const val STATE_CONNECTED = "connected"
        const val STATE_DISCONNECTED = "disconnected"
        const val STATE_ERROR = "error"

        private const val CHANNEL_ID = "vpn_status"
        private const val NOTIF_ID = 0x21
    }
}
