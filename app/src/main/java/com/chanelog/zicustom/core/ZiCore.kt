package com.chanelog.zicustom.core

import android.util.Log
import com.chanelog.zicustom.data.VpnConfig

/**
 * Thin abstraction over the native ZIVPN core.
 *
 * In the open-source release we keep the engine pluggable: when an `.aar`
 * built from the Go ZIVPN core (via gomobile) is dropped into `app/libs/`,
 * the [start] method will delegate to it via reflection. Otherwise, the
 * stub implementation logs the intended action so the rest of the app
 * (UI, VpnService, settings) can be exercised end-to-end.
 *
 * To wire a real engine:
 *   1. Build the gomobile aar exposing class `dev.zivpn.Core`
 *      with methods `start(host,port,password,sni,fd)` and `stop()`.
 *   2. Drop it into `app/libs/zivpn-core.aar` and rebuild.
 */
object ZiCore {
    private const val TAG = "ZiCore"

    @Volatile private var nativeStarted: Boolean = false

    fun start(cfg: VpnConfig, tunFd: Int): Boolean {
        Log.i(TAG, "start() host=${cfg.host} port=${cfg.port} sni=${cfg.sni} fd=$tunFd")
        return try {
            val cls = Class.forName("dev.zivpn.Core")
            val instance = cls.getDeclaredConstructor().newInstance()
            val m = cls.getMethod(
                "start",
                String::class.java, Int::class.javaPrimitiveType,
                String::class.java, String::class.java,
                Int::class.javaPrimitiveType
            )
            m.invoke(instance, cfg.host, cfg.port, cfg.password, cfg.sni, tunFd)
            nativeStarted = true
            true
        } catch (cnf: ClassNotFoundException) {
            Log.w(TAG, "Native ZIVPN core not bundled; running in stub mode.")
            // Stub mode: pretend connection succeeded so the UI flow can be tested.
            true
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to start native core", t)
            false
        }
    }

    fun stop() {
        Log.i(TAG, "stop()")
        if (!nativeStarted) return
        try {
            val cls = Class.forName("dev.zivpn.Core")
            val instance = cls.getDeclaredConstructor().newInstance()
            cls.getMethod("stop").invoke(instance)
        } catch (t: Throwable) {
            Log.w(TAG, "stop() ignored: ${t.message}")
        } finally {
            nativeStarted = false
        }
    }
}
