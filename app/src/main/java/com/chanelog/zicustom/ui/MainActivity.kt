package com.chanelog.zicustom.ui

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.text.method.ScrollingMovementMethod
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.chanelog.zicustom.R
import com.chanelog.zicustom.data.VpnConfig
import com.chanelog.zicustom.databinding.ActivityMainBinding
import com.chanelog.zicustom.vpn.ZiVpnService
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : AppCompatActivity() {

    private lateinit var b: ActivityMainBinding
    private val ts = SimpleDateFormat("HH:mm:ss", Locale.US)

    private val prepareLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            startVpnService()
        } else {
            log("VPN permission ditolak")
            Toast.makeText(this, "VPN permission ditolak", Toast.LENGTH_SHORT).show()
        }
    }

    private val notifPermLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { /* notifications are nice to have but optional */ }

    private val stateReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val state = intent?.getStringExtra(ZiVpnService.EXTRA_STATE) ?: return
            val msg = intent.getStringExtra(ZiVpnService.EXTRA_MESSAGE).orEmpty()
            renderState(state, msg)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityMainBinding.inflate(layoutInflater)
        setContentView(b.root)

        b.logView.movementMethod = ScrollingMovementMethod()
        loadConfigIntoUi()
        wireButtons()
        renderState(ZiVpnService.STATE_DISCONNECTED, "ready")
        log("ZiCustom siap")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) notifPermLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(ZiVpnService.BROADCAST_STATE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(stateReceiver, filter)
        }
    }

    override fun onStop() {
        try { unregisterReceiver(stateReceiver) } catch (_: Throwable) {}
        super.onStop()
    }

    private fun loadConfigIntoUi() {
        val cfg = VpnConfig.load(this)
        b.inputHost.setText(cfg.host)
        b.inputPort.setText(if (cfg.port == 0) VpnConfig.DEFAULT_PORT.toString() else cfg.port.toString())
        b.inputPassword.setText(cfg.password)
        b.inputSni.setText(cfg.sni)
        b.inputMtu.setText(cfg.mtu.toString())
    }

    private fun readConfigFromUi(): VpnConfig? {
        val host = b.inputHost.text?.toString()?.trim().orEmpty()
        val port = b.inputPort.text?.toString()?.trim()?.toIntOrNull() ?: 0
        val password = b.inputPassword.text?.toString().orEmpty()
        val sni = b.inputSni.text?.toString()?.trim().orEmpty().ifBlank { VpnConfig.DEFAULT_SNI }
        val mtu = b.inputMtu.text?.toString()?.trim()?.toIntOrNull() ?: VpnConfig.DEFAULT_MTU

        if (host.isBlank()) { toast(getString(R.string.error_host_required)); return null }
        if (port !in 1..65535) { toast(getString(R.string.error_port_required)); return null }
        if (password.isBlank()) { toast(getString(R.string.error_password_required)); return null }

        return VpnConfig(host, port, password, sni, mtu)
    }

    private fun wireButtons() {
        b.btnSave.setOnClickListener {
            val cfg = readConfigFromUi() ?: return@setOnClickListener
            VpnConfig.save(this, cfg)
            log("Config disimpan")
            toast("Config disimpan")
        }
        b.btnClearLog.setOnClickListener { b.logView.text = "" }

        b.btnConnect.setOnClickListener {
            val cfg = readConfigFromUi() ?: return@setOnClickListener
            VpnConfig.save(this, cfg)
            if (b.btnConnect.text == getString(R.string.action_disconnect)) {
                stopVpnService()
            } else {
                requestVpnPermissionAndStart()
            }
        }
    }

    private fun requestVpnPermissionAndStart() {
        val prepare = VpnService.prepare(this)
        if (prepare == null) startVpnService() else prepareLauncher.launch(prepare)
    }

    private fun startVpnService() {
        val intent = Intent(this, ZiVpnService::class.java).setAction(ZiVpnService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        log("Mengirim perintah start ke service")
    }

    private fun stopVpnService() {
        val intent = Intent(this, ZiVpnService::class.java).setAction(ZiVpnService.ACTION_STOP)
        startService(intent)
        log("Mengirim perintah stop ke service")
    }

    private fun renderState(state: String, msg: String) {
        when (state) {
            ZiVpnService.STATE_CONNECTING -> {
                b.statusText.setText(R.string.status_connecting)
                b.statusText.setTextColor(getColor(R.color.status_connecting))
                b.btnConnect.setText(R.string.action_disconnect)
            }
            ZiVpnService.STATE_CONNECTED -> {
                b.statusText.setText(R.string.status_connected)
                b.statusText.setTextColor(getColor(R.color.status_connected))
                b.btnConnect.setText(R.string.action_disconnect)
            }
            ZiVpnService.STATE_ERROR -> {
                b.statusText.setText(R.string.status_error)
                b.statusText.setTextColor(getColor(R.color.status_disconnected))
                b.btnConnect.setText(R.string.action_connect)
            }
            else -> {
                b.statusText.setText(R.string.status_disconnected)
                b.statusText.setTextColor(getColor(R.color.status_disconnected))
                b.btnConnect.setText(R.string.action_connect)
            }
        }
        if (msg.isNotBlank()) log("[$state] $msg")
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()

    private fun log(line: String) {
        val time = ts.format(Date())
        b.logView.append("[$time] $line\n")
    }
}
