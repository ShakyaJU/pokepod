package com.shakyaju.pokepod

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runs `widgetBackgroundMain` in a brief headless Flutter engine.
 *
 * The entrypoint is the app's own code (the same selection, widget-store and
 * reminder logic the foreground app uses), so nothing is duplicated natively:
 * the engine lives only until Dart signals `done` on [CHANNEL_NAME], or until
 * the safety timeout fires, and is then destroyed.
 *
 * `FlutterEngine(context)` registers the generated plugins itself, which is why
 * they are deliberately *not* registered a second time here. The callback given
 * to [start] is always invoked on the main thread, exactly once.
 */
object WidgetBackgroundRunner {
  private const val TAG = "WidgetBackgroundRunner"
  private const val CHANNEL_NAME = "pokepod/widget_bg"
  private const val ENTRYPOINT = "widgetBackgroundMain"
  private const val TIMEOUT_MS = 25_000L

  private val running = AtomicBoolean(false)

  /// Starts the background refresh. [onFinished] is called when the run ends,
  /// however it ends; calling [start] again while one is in flight returns
  /// immediately, because the run already under way covers the request.
  fun start(context: Context, onFinished: (() -> Unit)? = null) {
    if (!running.compareAndSet(false, true)) {
      onFinished?.invoke()
      return
    }

    val appContext = context.applicationContext
    val mainHandler = Handler(Looper.getMainLooper())

    var wakeLock: PowerManager.WakeLock? = null
    var engine: FlutterEngine? = null
    var channel: MethodChannel? = null
    var timeoutRunnable: Runnable? = null
    var finished = false

    fun finish() {
      if (finished) {
        return
      }
      finished = true
      timeoutRunnable?.let {
        try {
          mainHandler.removeCallbacks(it)
        } catch (e: Exception) {
          // Nothing left to remove.
        }
      }
      try {
        channel?.setMethodCallHandler(null)
      } catch (e: Exception) {
        // The channel may never have been created.
      }
      try {
        engine?.destroy()
      } catch (e: Exception) {
        // Destroying a half-started engine is best-effort.
      }
      try {
        if (wakeLock?.isHeld == true) {
          wakeLock?.release()
        }
      } catch (e: Exception) {
        // A released lock is the desired end state anyway.
      }
      running.set(false)
      onFinished?.invoke()
    }

    timeoutRunnable =
        Runnable {
          Log.w(TAG, "Background refresh timed out after ${TIMEOUT_MS}ms")
          finish()
        }

    try {
      wakeLock =
          (appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager)
              ?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "pokepod:widget_refresh")
              ?.apply {
                setReferenceCounted(false)
                acquire(TIMEOUT_MS + 5_000L)
              }
    } catch (e: Exception) {
      wakeLock = null
    }

    try {
      val loader = FlutterInjector.instance().flutterLoader()
      loader.startInitialization(appContext)
      loader.ensureInitializationComplete(appContext, null)

      val flutterEngine = FlutterEngine(appContext)
      engine = flutterEngine

      val methodChannel =
          MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
      channel = methodChannel
      methodChannel.setMethodCallHandler { call, result ->
        if (call.method == "done") {
          result.success(null)
          finish()
        } else {
          result.notImplemented()
        }
      }

      mainHandler.postDelayed(timeoutRunnable!!, TIMEOUT_MS)

      flutterEngine.dartExecutor.executeDartEntrypoint(
          DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
      )
    } catch (e: Exception) {
      Log.e(TAG, "Could not start the background refresh", e)
      finish()
    }
  }
}
