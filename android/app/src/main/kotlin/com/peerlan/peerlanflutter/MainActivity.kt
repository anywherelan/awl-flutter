package com.peerlan.peerlanflutter

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import peerlan.Peerlan

class MainActivity : FlutterActivity() {
    private val CHANNEL = "peerlan.net"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start_server" -> {
                    Peerlan.initServer(this.filesDir.absolutePath)

                    val port = Peerlan.getPort()
                    result.success(port)

//                    if (batteryLevel != -1) {
//                    } else {
//                        result.error("UNAVAILABLE", "Battery level not available.", null)
//                    }
                }
                "stop_server" -> {
                    Peerlan.stopServer()
                    result.success(null)
                }
                "import_config" -> {
                    try {
                        val text = call.argument<String>("config")
                        Peerlan.importConfig(text)
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
