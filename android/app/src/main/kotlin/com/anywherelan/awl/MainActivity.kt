package com.anywherelan.awl

import android.content.Intent
import android.net.VpnService
import android.os.Build
import androidx.annotation.NonNull
import anywherelan.Anywherelan
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger.TaskQueue
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec


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
                    val startedApiAddress = Anywherelan.getApiAddress()
                    if (startedApiAddress != "") {
                        result.success(startedApiAddress)
                        return@setMethodCallHandler
                    }

                    Anywherelan.setup(this.filesDir.absolutePath)
                    val config = AppConfig.fromJson(Anywherelan.getConfig())
                    var tunFd = 0

                    if (!config.vpn.disableVPNInterface) {
                        val service = MyVpnService()
                        val requestPermissionIntent = VpnService.prepare(this.context)
                        if (requestPermissionIntent != null) {
                            result.error("error", "vpn not authorized", null)
                            this.startActivityForResult(requestPermissionIntent, 4444)
                            return@setMethodCallHandler
                        }
                        context.startService(Intent(context, MyVpnService::class.java))


                        val tunnelName = config.vpn.interfaceName
                        val ipNetParts = config.vpn.ipNet.split("/")
                        if (ipNetParts.size != 2) {
                            throw Exception("Invalid ipNet format: ${config.vpn.ipNet}")
                        }
                        val networkAddress = ipNetParts[0]
                        val networkAddressMask = ipNetParts[1].toInt()

                        val builder: VpnService.Builder = service.builder
                        builder.setSession(tunnelName)
                        builder.addAddress(networkAddress, networkAddressMask)
                        builder.setMtu(3500)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            builder.setBlocking(true)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            builder.setMetered(false)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            service.setUnderlyingNetworks(null)
                        }

                        builder.establish().use { tun ->
                            if (tun == null) throw Exception("TUN_CREATION_ERROR")
                            tunFd = tun!!.detachFd()
                        }
                    }

                    try {
                        Anywherelan.startServer(tunFd)
                        val apiAddress = Anywherelan.getApiAddress()
                        result.success(apiAddress)
                    } catch (e: Exception) {
                        result.error("error", e.message, null)
                    }
                }
                "stop_server" -> {
                    Anywherelan.stopServer()
                    result.success(null)
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
}

class MyVpnService : android.net.VpnService() {
    val builder: Builder
        get() = Builder()

    override fun onDestroy() {
        Anywherelan.stopServer()
        super.onDestroy()
    }
}
