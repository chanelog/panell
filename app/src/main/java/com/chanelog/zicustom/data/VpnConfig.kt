package com.chanelog.zicustom.data

import android.content.Context
import androidx.preference.PreferenceManager

/**
 * Holds the user-supplied ZIVPN connection parameters.
 *
 * The fields mirror what zivpn / mini-zivpn-style clients accept:
 *  - host:    server address (FQDN or IP)
 *  - port:    UDP port (Hysteria-based)
 *  - password: UDP obfuscation password (often "zi" by default in public configs)
 *  - sni:     TLS SNI used for the QUIC handshake
 *  - mtu:     tunnel MTU (defaults to 1380 for QUIC over UDP)
 */
data class VpnConfig(
    val host: String,
    val port: Int,
    val password: String,
    val sni: String,
    val mtu: Int
) {
    companion object {
        const val DEFAULT_PORT = 6666
        const val DEFAULT_SNI = "www.cloudflare.com"
        const val DEFAULT_MTU = 1380
        const val DEFAULT_PASSWORD = "zi"

        private const val KEY_HOST = "cfg_host"
        private const val KEY_PORT = "cfg_port"
        private const val KEY_PASS = "cfg_password"
        private const val KEY_SNI = "cfg_sni"
        private const val KEY_MTU = "cfg_mtu"

        fun load(context: Context): VpnConfig {
            val sp = PreferenceManager.getDefaultSharedPreferences(context)
            return VpnConfig(
                host = sp.getString(KEY_HOST, "") ?: "",
                port = sp.getInt(KEY_PORT, DEFAULT_PORT),
                password = sp.getString(KEY_PASS, DEFAULT_PASSWORD) ?: DEFAULT_PASSWORD,
                sni = sp.getString(KEY_SNI, DEFAULT_SNI) ?: DEFAULT_SNI,
                mtu = sp.getInt(KEY_MTU, DEFAULT_MTU)
            )
        }

        fun save(context: Context, cfg: VpnConfig) {
            PreferenceManager.getDefaultSharedPreferences(context).edit().apply {
                putString(KEY_HOST, cfg.host)
                putInt(KEY_PORT, cfg.port)
                putString(KEY_PASS, cfg.password)
                putString(KEY_SNI, cfg.sni)
                putInt(KEY_MTU, cfg.mtu)
                apply()
            }
        }
    }
}
