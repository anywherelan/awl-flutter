package com.anywherelan.awl

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.provider.Settings
import androidx.annotation.NonNull
import anywherelan.Anywherelan
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger.TaskQueue
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec


// MainActivity bridges the Flutter UI to MyVpnService, which owns the awl
// backend. The activity only asks for the VPN permission, which needs an
// activity to show its dialog.
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
                    val startedApiAddress = Anywherelan.getApiAddress()
                    if (startedApiAddress != "") {
                        result.success(startedApiAddress)
                        return@setMethodCallHandler
                    }

                    Anywherelan.setup(this.filesDir.absolutePath)
                    val config = AppConfig.fromJson(Anywherelan.getConfig())
                    if (!config.vpn.disableVPNInterface) {
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
                    try {
                        MyVpnService.instance?.reconfigure()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("error", e.message, null)
                    }
                }
                "stop_server" -> {
                    val service = MyVpnService.instance
                    if (service != null) {
                        service.stop()
                    } else {
                        Anywherelan.stopServer()
                    }
                    result.success(null)
                }
                "server_status" -> {
                    // The API address of the running backend, "" when stopped.
                    // awl may start and stop without the app (Always-on VPN,
                    // the VPN being revoked), so the app asks on resume. The
                    // lockdown option may have changed meanwhile in the VPN
                    // settings.
                    MyVpnService.instance?.updateNotification()
                    result.success(Anywherelan.getApiAddress())
                }
                "always_on_status" -> {
                    val service = MyVpnService.instance
                    service?.updateNotification()
                    result.success(
                        mapOf(
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
                    try {
                        val text = call.argument<String>("config")
                        Anywherelan.importConfig(text)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("error", e.message, null)
                    }
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
            // Off the main thread: start waits for the service, which starts
            // on the main thread.
            Thread { startAwl(result) }.start()
        } else {
            result.error("error", "vpn not authorized", null)
        }
    }

    private fun startAwl(result: MethodChannel.Result) {
        var service: MyVpnService? = null
        try {
            service = MyVpnService.start(this)
            val apiAddress = service.startAwl()
            result.success(apiAddress)
        } catch (e: Exception) {
            service?.stop()
            result.error("error", e.message, null)
        }
    }

    companion object {
        private const val VPN_PERMISSION_REQUEST = 4444

        // The start_server call waiting for the answer to the VPN permission
        // request. Kept here rather than in the activity, since the answer may
        // reach a new activity instance (e.g. after a rotation).
        private val pendingStartLock = Any()
        private var pendingStart: MethodChannel.Result? = null
    }
}
