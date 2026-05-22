package com.chanelog.zicustom.core

import android.util.Log
import com.chanelog.zicustom.data.VpnConfig

/**
 * Thin Kotlin façade over the gomobile-built native ZIVPN core.
 *
 * The native library is built from the Go module under `core/` via
 * `gomobile bind`, producing `app/libs/zivpn-core.aar`. The bound class
 * is `dev.zivpn.Core` with two methods:
 *
 *   start(host: String, port: Long, password: String, sni: String, fd: Long): Throwable?
 *   stop(): Throwable?
 *
 * gomobile maps Go `int` to Java `long`, so we pass [Long] across the boundary.
 *
 * If the AAR is missing (CI native build failed) we return false and the
 * VpnService surfaces an error message to the UI — no silent stubbing.
 */
object ZiCore {
    private const val TAG = "ZiCore"

    @Volatile private var nativeStarted: Boolean = false
    @Volatile private var lastError: String? = null

    fun lastError(): String? = lastError

    fun isAvailable(): Boolean = try {
        Class.forName("dev.zivpn.Core"); true
    } catch (_: ClassNotFoundException) { false }

    fun start(cfg: VpnConfig, tunFd: Int): Boolean {
        Log.i(TAG, "start() host=${cfg.host} port=${cfg.port} sni=${cfg.sni} fd=$tunFd")
        lastError = null
        return try {
            val cls = Class.forName("dev.zivpn.Core")
            val instance = cls.getDeclaredConstructor().newInstance()
            // gomobile signature: Start(host string, port int, password, sni string, fd int) error
            val method = cls.methods.firstOrNull { it.name == "start" }
                ?: cls.methods.firstOrNull { it.name == "Start" }
                ?: error("dev.zivpn.Core has no start() method")
            method.invoke(instance, cfg.host, cfg.port.toLong(), cfg.password, cfg.sni, tunFd.toLong())
            nativeStarted = true
            true
        } catch (cnf: ClassNotFoundException) {
            lastError = "Native core not bundled (gomobile build failed in CI)"
            Log.e(TAG, lastError, cnf)
            false
        } catch (t: Throwable) {
            // gomobile bound methods throw the wrapped Go error as cause.
            val cause = t.cause ?: t
            lastError = cause.message ?: cause.javaClass.simpleName
            Log.e(TAG, "start() failed: $lastError", t)
            false
        }
    }

    fun stop() {
        Log.i(TAG, "stop()")
        if (!nativeStarted) return
        try {
            val cls = Class.forName("dev.zivpn.Core")
            val instance = cls.getDeclaredConstructor().newInstance()
            val method = cls.methods.firstOrNull { it.name == "stop" }
                ?: cls.methods.firstOrNull { it.name == "Stop" }
            method?.invoke(instance)
        } catch (t: Throwable) {
            Log.w(TAG, "stop() ignored: ${t.message}")
        } finally {
            nativeStarted = false
        }
    }
}
