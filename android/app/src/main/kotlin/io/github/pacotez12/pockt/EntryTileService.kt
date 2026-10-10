package io.github.pacotez12.pockt

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class EntryTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        tile.state = Tile.STATE_INACTIVE
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()

        val uri = Uri.parse("pockt://entry")
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            this,
            MainActivity::class.java,
            uri
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(pendingIntent)
        } else {
            val intent = Intent(this, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = uri
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
