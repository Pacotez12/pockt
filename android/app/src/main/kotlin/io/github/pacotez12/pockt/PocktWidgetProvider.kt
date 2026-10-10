package io.github.pacotez12.pockt

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PocktWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.pockt_widget)

            // Intent para abrir pockt://entry al tocar el orbe o el botón +
            val entryPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("pockt://entry")
            )
            views.setOnClickPendingIntent(R.id.widget_brand_container, entryPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_button_plus, entryPendingIntent)

            val count = widgetData.getInt("category_count", 0)

            val containerIds = intArrayOf(
                R.id.bubble_container_0,
                R.id.bubble_container_1,
                R.id.bubble_container_2,
                R.id.bubble_container_3
            )
            val bgIds = intArrayOf(
                R.id.bubble_bg_0,
                R.id.bubble_bg_1,
                R.id.bubble_bg_2,
                R.id.bubble_bg_3
            )
            val iconIds = intArrayOf(
                R.id.bubble_icon_0,
                R.id.bubble_icon_1,
                R.id.bubble_icon_2,
                R.id.bubble_icon_3
            )

            for (i in 0 until 4) {
                val catId = widgetData.getString("category_id_$i", null)
                if (i < count && !catId.isNullOrEmpty()) {
                    views.setViewVisibility(containerIds[i], View.VISIBLE)

                    // Color de la categoría
                    val color = getColor(widgetData, "category_color_$i")
                    if (color != 0) {
                        views.setInt(bgIds[i], "setColorFilter", color)
                    }

                    // Ícono de la categoría
                    val iconKey = widgetData.getString("category_icon_$i", null)
                    val iconRes = getDrawableForIconKey(iconKey)
                    views.setImageViewResource(iconIds[i], iconRes)

                    // Deep link específico para esta categoría: pockt://entry?category=<id>
                    val catPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pockt://entry?category=$catId")
                    )
                    views.setOnClickPendingIntent(containerIds[i], catPendingIntent)
                } else {
                    views.setViewVisibility(containerIds[i], View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun getColor(prefs: SharedPreferences, key: String): Int {
        return try {
            prefs.getInt(key, 0)
        } catch (_: ClassCastException) {
            prefs.getLong(key, 0L).toInt()
        }
    }

    private fun getDrawableForIconKey(key: String?): Int {
        return when (key) {
            "fork-knife" -> R.drawable.ic_fork_knife
            "car-profile" -> R.drawable.ic_car_profile
            "house-line" -> R.drawable.ic_house_line
            "heartbeat" -> R.drawable.ic_heartbeat
            "popcorn" -> R.drawable.ic_popcorn
            "lightning" -> R.drawable.ic_lightning
            "graduation-cap" -> R.drawable.ic_graduation_cap
            "gift" -> R.drawable.ic_gift
            "t-shirt" -> R.drawable.ic_t_shirt
            "package" -> R.drawable.ic_package
            "briefcase" -> R.drawable.ic_briefcase
            "shopping-cart" -> R.drawable.ic_shopping_cart
            else -> R.drawable.ic_tag
        }
    }
}
