package com.shakyaju.pokepod

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * The daily challenge resets at local midnight, so both the reminder and the
 * daily widget refresh are measured against the device's own clock and zone.
 * Moving either one moves that boundary, which can leave an already-armed
 * reminder pointing at the wrong instant — worst case, at one *after* the
 * reset it is meant to precede.
 *
 * Two corrections run together: the widget alarm is re-armed natively, and the
 * same headless refresh the midnight alarm uses re-evaluates the reminder from
 * the new clock. Nothing depends on the app being opened again.
 *
 * Both actions are protected system broadcasts, so nothing else can send them
 * to this exported receiver.
 */
class ClockChangeReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
      Intent.ACTION_TIME_CHANGED,
      Intent.ACTION_TIMEZONE_CHANGED,
      -> {
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
  }
}
