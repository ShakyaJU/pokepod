package com.shakyaju.pokepod

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Alarms do not survive a reboot or an app update, so the daily widget refresh
 * is armed again as soon as either happens. Widgets also re-render from the
 * last stored data the moment the launcher asks for them.
 */
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
      Intent.ACTION_BOOT_COMPLETED,
      Intent.ACTION_MY_PACKAGE_REPLACED,
      -> SpecimenWidgetScheduling.scheduleNextDailyRefresh(context)
    }
  }
}
