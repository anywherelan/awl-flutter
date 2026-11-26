package com.anywherelan.awl

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger.TaskQueue
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.util.concurrent.CompletionException
import java.util.concurrent.ExecutionException


// MainActivity bridges the Flutter UI to MyVpnService, which owns the awl
// backend. The activity only asks for the VPN permission, which needs an
// activity to show its dialog, and forwards everything else to the service.
class MainActivity : FlutterActivity() {
    private val CHANNEL = "anywherelan"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Get the binary messenger
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 2. Create a background task queue from the messenger
        val taskQueue: TaskQueue = messenger.makeBackgroundTaskQueue()

        // 3. Provide the taskQueue when creating the MethodChannel
        val channel = MethodChannel(messenger, CHANNEL, StandardMethodCodec.INSTANCE, taskQueue)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start_server" -> {
                    // Already running, e.g. started by Always-on VPN at boot.
                    val startedApiAddress = MyVpnService.apiAddress
                    if (startedApiAddress != "") {
                        result.success(startedApiAddress)
                        return@setMethodCallHandler
                    }

                    if (MyVpnService.needsVpnInterface(this)) {
                        val requestPermissionIntent = VpnService.prepare(this.context)
                        if (requestPermissionIntent != null) {
                            // Ask once and answer the call when the user has
                            // decided, in onActivityResult.
                            synchronized(pendingStartLock) {
                                if (pendingStart != null) {
                                    result.error("error", "vpn permission request already open", null)
                                    return@setMethodCallHandler
                                }
                                pendingStart = result
                            }
                            this.startActivityForResult(requestPermissionIntent, VPN_PERMISSION_REQUEST)
                            return@setMethodCallHandler
                        }
                    }

                    startAwl(result)
                }
                "reconfigure_vpn" -> {
                    runOnService(result) { MyVpnService.reconfigure().get() }
                }
                "stop_server" -> {
                    runOnService(result) { MyVpnService.stop().get() }
                }
                "server_status" -> {
                    // The API address of the running backend, "" when stopped.
                    // awl may start and stop without the app (Always-on VPN,
                    // the VPN being revoked), so the app asks on resume. The
                    // lockdown option may have changed meanwhile in the VPN
                    // settings.
                    MyVpnService.owner?.updateNotification()
                    result.success(MyVpnService.apiAddress)
                }
                "always_on_status" -> {
                    // Android reports Always-on VPN only since Android 10, and
                    // only to a running VPN service.
                    val service = MyVpnService.owner
                    result.success(
                        mapOf(
                            "known" to (service != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q),
                            "alwaysOn" to (service?.isAlwaysOnEnabled() ?: false),
                            "lockdown" to (service?.isLockdownModeEnabled() ?: false),
                            "routesAllTraffic" to (service?.routesAllTraffic ?: false),
                        )
                    )
                }
                "open_vpn_settings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("error", e.message, null)
                    }
                }
                "import_config" -> {
                    val text = call.argument<String>("config")
                    runOnService(result) { MyVpnService.importConfig(this, text).get() }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_PERMISSION_REQUEST) return
        val result = synchronized(pendingStartLock) {
            pendingStart.also { pendingStart = null }
        } ?: return
        if (resultCode == Activity.RESULT_OK) {
            startAwl(result)
        } else {
            result.error("error", "vpn not authorized", null)
        }
    }

    private fun startAwl(result: MethodChannel.Result) {
        MyVpnService.start(applicationContext).whenComplete { apiAddress, e ->
            if (e == null) {
                result.success(apiAddress)
            } else {
                result.error("error", unwrap(e).message, null)
            }
        }
    }

    // runOnService answers the call with the outcome of a request the service
    // ran on its worker.
    private fun runOnService(result: MethodChannel.Result, request: () -> Unit) {
        try {
            request()
            result.success(null)
        } catch (e: Exception) {
            result.error("error", unwrap(e).message, null)
        }
    }

    private fun unwrap(e: Throwable): Throwable =
        if ((e is ExecutionException || e is CompletionException) && e.cause != null) e.cause!! else e

    companion object {
        private const val VPN_PERMISSION_REQUEST = 4444

        // The start_server call waiting for the answer to the VPN permission
        // request. Kept here rather than in the activity, since the answer may
        // reach a new activity instance (e.g. after a rotation).
        private val pendingStartLock = Any()
        private var pendingStart: MethodChannel.Result? = null
    }
}
