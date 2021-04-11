package com.anywherelan.awl

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import anywherelan.Anywherelan

class MainActivity : FlutterActivity() {
    private val CHANNEL = "anywherelan"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start_server" -> {
                    Anywherelan.initServer(this.filesDir.absolutePath)

                    val port = Anywherelan.getPort()
                    result.success(port)

//                    if (batteryLevel != -1) {
//                    } else {
//                        result.error("UNAVAILABLE", "Battery level not available.", null)
//                    }
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
