package com.shakyaju.pokepod

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The midnight widget refresh must be armed whatever brought the app
        // up (fresh install, reboot, app update, ordinary launch).
        SpecimenWidgetScheduling.scheduleNextDailyRefresh(this)
    }

    /// Extra carrying the route a widget or notification tap requested:
    /// currently only "specimen" (open today's Specimen of the Day).
    private var pendingWidgetRoute: String? = null

    private var routeChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pokepod/platform"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingRoute" -> {
                    val route = pendingWidgetRoute
                    pendingWidgetRoute = null
                    result.success(route)
                }
                "openNotificationSettings" -> {
                    try {
                        // Opens this app's own notification screen (API 26+).
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            .putExtra(
                                Settings.EXTRA_APP_PACKAGE,
                                packageName
                            )
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Some OEMs remove this screen; fall back to app info.
                        try {
                            val fallback = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(fallback)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("unavailable", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        routeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pokepod/routes"
        )
        captureWidgetRoute(intent)
    }

    /// Remembers the tap route from the launch intent; Dart asks for it once
    /// its handler is listening, so a cold start cannot lose the tap.
    private fun captureWidgetRoute(intent: Intent?) {
        val route = intent?.getStringExtra(EXTRA_ROUTE)
        if (route != null) {
            pendingWidgetRoute = route
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetRoute(intent)
        deliverPendingRoute()
    }

    private fun deliverPendingRoute() {
        val route = pendingWidgetRoute ?: return
        val channel = routeChannel ?: return
        channel.invokeMethod(
            "openRoute",
            route,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    pendingWidgetRoute = null
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?
                ) {
                    // Dart will pick the route up through getPendingRoute.
                }

                override fun notImplemented() {
                    // Handler not installed yet: same fallback as above.
                }
            }
        )
    }

    companion object {
        /// Intent extra shared with `SpecimenWidgetProvider` (widget taps) and
        /// read by Dart through the `pokepod/routes` channel.
        const val EXTRA_ROUTE = "pokepod_route"
        const val ROUTE_SPECIMEN = "specimen"
    }
}
