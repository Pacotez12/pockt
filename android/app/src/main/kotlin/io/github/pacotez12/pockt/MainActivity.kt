package io.github.pacotez12.pockt

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pockt/secure").setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Flutter no pide una tasa de refresco alta por su cuenta: en pantallas
    // adaptativas (Samsung) la app queda en 60 Hz. Pedimos el modo de mayor
    // frecuencia con la misma resolución que el modo actual.
    private fun requestHighestRefreshRate() {
        val display: Display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }) ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
        // Con refresco variable el modo ya puede ser el de 120 Hz y aun así
        // correr a 60: además del modo, se pide explícitamente la frecuencia.
        window.attributes = window.attributes.apply {
            preferredDisplayModeId = best.modeId
            preferredRefreshRate = best.refreshRate
        }
    }
}
