package io.github.pacotez12.pockt

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
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
