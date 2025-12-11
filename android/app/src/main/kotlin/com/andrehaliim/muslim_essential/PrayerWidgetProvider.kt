package com.andrehaliim.muslim_essential

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget_layout)

            val prefs = HomeWidgetPlugin.getData(context)

            // Location
            views.setTextViewText(R.id.location_name, prefs.getString("location_name", "-"))

            // Prayer times
            views.setTextViewText(R.id.fajr_time, prefs.getString("fajr_time", "--:--"))
            views.setTextViewText(R.id.dhuhr_time, prefs.getString("dhuhr_time", "--:--"))
            views.setTextViewText(R.id.asr_time, prefs.getString("asr_time", "--:--"))
            views.setTextViewText(R.id.maghrib_time, prefs.getString("maghrib_time", "--:--"))
            views.setTextViewText(R.id.isha_time, prefs.getString("isha_time", "--:--"))

            // 🔔 Notification icons
            val fajrNotif = prefs.getBoolean("fajr_notification", false)
            views.setImageViewResource(
                R.id.fajr_notification,
                if (fajrNotif) R.drawable.ic_notification_on else R.drawable.ic_notification_off
            )

            val dhuhrNotif = prefs.getBoolean("dhuhr_notification", false)
            views.setImageViewResource(
                R.id.dhuhr_notification,
                if (dhuhrNotif) R.drawable.ic_notification_on else R.drawable.ic_notification_off
            )

            val asrNotif = prefs.getBoolean("asr_notification", false)
            views.setImageViewResource(
                R.id.asr_notification,
                if (asrNotif) R.drawable.ic_notification_on else R.drawable.ic_notification_off
            )

            val maghribNotif = prefs.getBoolean("maghrib_notification", false)
            views.setImageViewResource(
                R.id.maghrib_notification,
                if (maghribNotif) R.drawable.ic_notification_on else R.drawable.ic_notification_off
            )

            val ishaNotif = prefs.getBoolean("isha_notification", false)
            views.setImageViewResource(
                R.id.isha_notification,
                if (ishaNotif) R.drawable.ic_notification_on else R.drawable.ic_notification_off
            )

            // ✔ Tracker icons
            val fajrCheck = prefs.getBoolean("fajr_check", false)
            views.setImageViewResource(
                R.id.fajr_check,
                if (fajrCheck) R.drawable.ic_check_circle else R.drawable.ic_circle_outline
            )

            val dhuhrCheck = prefs.getBoolean("dhuhr_check", false)
            views.setImageViewResource(
                R.id.dhuhr_check,
                if (dhuhrCheck) R.drawable.ic_check_circle else R.drawable.ic_circle_outline
            )

            val asrCheck = prefs.getBoolean("asr_check", false)
            views.setImageViewResource(
                R.id.asr_check,
                if (asrCheck) R.drawable.ic_check_circle else R.drawable.ic_circle_outline
            )

            val maghribCheck = prefs.getBoolean("maghrib_check", false)
            views.setImageViewResource(
                R.id.maghrib_check,
                if (maghribCheck) R.drawable.ic_check_circle else R.drawable.ic_circle_outline
            )

            val ishaCheck = prefs.getBoolean("isha_check", false)
            views.setImageViewResource(
                R.id.isha_check,
                if (ishaCheck) R.drawable.ic_check_circle else R.drawable.ic_circle_outline
            )

            //Date
            views.setTextViewText(R.id.date, prefs.getString("date_time", "-"))

            // Click action to open Flutter app
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.prayer_widget_root, pendingIntent)

            // Intent to launch Qibla Compass
            val qiblaIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                putExtra("fromWidget", "qibla")
            }

            val qiblaPendingIntent = PendingIntent.getActivity(
                context,
                1,
                qiblaIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.qibla_button, qiblaPendingIntent)

            // Intent to launch Set Tracker
            val trackerIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                putExtra("fromWidget", "tracker")
            }

            val trackerPendingIntent = PendingIntent.getActivity(
                context,
                2,
                trackerIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.track_button, trackerPendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
