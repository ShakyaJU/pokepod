package com.shakyaju.pokepod

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * The one alarm that keeps home-screen widgets correct while the app is closed.
 *
 * Shortly after local midnight it fires [SpecimenRefreshReceiver], which runs
 * the app's own Dart logic in a brief headless engine (see [WidgetBackgroundRunner])
 * and then re-arms itself for the next day. The alarm is deliberately inexact
 * (`setAndAllowWhileIdle`): the refresh is only *dated*, not timed, and an
 * inexact alarm needs no exact-alarm permission and survives Doze.
 */
object SpecimenWidgetScheduling {
  private const val REQUEST_CODE = 7421
  private const val ACTION_DAILY_REFRESH = "com.shakyaju.pokepod.action.DAILY_WIDGET_REFRESH"
  private const val REFRESH_HOUR = 0
  private const val REFRESH_MINUTE = 10

  /// Arms the next daily refresh. Safe to call as often as it likes (app start,
  /// boot, package update, after every fire): the previous alarm is replaced
  /// because the PendingIntent matches.
  fun scheduleNextDailyRefresh(context: Context) {
    val appContext = context.applicationContext
    val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
    val pendingIntent = dailyRefreshIntent(appContext) ?: return
    val triggerAt = nextRefreshTime()
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
      } else {
        alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
      }
    } catch (e: SecurityException) {
      // A device policy that forbids alarms must never crash the app; the
      // widgets then simply refresh whenever the app is next opened.
    }
  }

  private fun dailyRefreshIntent(context: Context): PendingIntent? =
      try {
        val intent =
            Intent(context, SpecimenRefreshReceiver::class.java).apply { action = ACTION_DAILY_REFRESH }
        PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
      } catch (e: Exception) {
        null
      }

  /// Today's 00:10 in local time, or tomorrow's when that moment has passed.
  private fun nextRefreshTime(): Long {
    val now = Calendar.getInstance()
    val next =
        (now.clone() as Calendar).apply {
          set(Calendar.HOUR_OF_DAY, REFRESH_HOUR)
          set(Calendar.MINUTE, REFRESH_MINUTE)
          set(Calendar.SECOND, 0)
          set(Calendar.MILLISECOND, 0)
          if (timeInMillis <= now.timeInMillis) {
            add(Calendar.DAY_OF_YEAR, 1)
          }
        }
    return next.timeInMillis
  }
}
