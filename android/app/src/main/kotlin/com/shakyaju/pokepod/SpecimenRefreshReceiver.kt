package com.shakyaju.pokepod

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Runs the midnight refresh: the app's own Dart entrypoint recomputes today's
 * Specimen of the Day into the widget store and re-arms today's streak
 * reminder, then Android is asked to re-render the widgets.
 *
 * The next alarm is armed first, so an interrupted run still cannot cost a day.
 * [goAsync] keeps the process alive while the headless engine works, and the
 * runner always calls back (work done, failure or timeout) so the pending
 * result is finished exactly once.
 */
class SpecimenRefreshReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    SpecimenWidgetScheduling.scheduleNextDailyRefresh(context)

    val pendingResult = goAsync()
    var finished = false
    val finish: () -> Unit = {
      if (!finished) {
        finished = true
        try {
          pendingResult.finish()
        } catch (e: Exception) {
          // The system may already have given up on this broadcast.
        }
      }
    }
    WidgetBackgroundRunner.start(context.applicationContext, onFinished = finish)
  }
}
