package com.anywherelan.awl

import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.system.OsConstants
import androidx.annotation.NonNull
import anywherelan.Anywherelan
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "anywherelan"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start_server" -> {
                    val service = MyVpnService()
                    val requestPermissionIntent = VpnService.prepare(this.context)
                    if (requestPermissionIntent != null) {
                        result.error("error", "vpn not authorized", null)
                        this.startActivityForResult(requestPermissionIntent, 4444)
                    }
                    context.startService(Intent(context, MyVpnService::class.java))


                    val builder: VpnService.Builder = service.builder
                    // TODO: remove hardcode
                    val tunnelName = "awl0"
                    val networkAddress = "10.66.0.1"
                    val networkAddressMask = 24
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

                    var tunFd = 0
                    builder.establish().use { tun ->
                        if (tun == null) throw Exception("TUN_CREATION_ERROR")
                        tunFd = tun.detachFd()
                    }

                    Anywherelan.initServer(this.filesDir.absolutePath, tunFd)
                    val port = Anywherelan.getPort()
                    result.success(port)
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
        // TODO
        super.onDestroy()
    }

}
