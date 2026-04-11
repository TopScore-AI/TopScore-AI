package com.topscoreapp.ai

import com.topscoreapp.ai.R
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class StudyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.topscore_widget).apply {
                
                // Get data from Flutter
                val subject = widgetData.getString("study_subject", "Biology")
                val progress = widgetData.getFloat("study_progress", 0.0f)
                val statusText = widgetData.getString("study_status", "0/30 mins completed")

                setTextViewText(R.id.study_subject, "Next: $subject")
                setTextViewText(R.id.study_status, statusText)
                setProgressBar(R.id.progress_bar, 100, (progress * 100).toInt(), false)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
