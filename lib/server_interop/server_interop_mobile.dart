import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:anywherelan/api.dart';
import 'package:flutter/material.dart';

Future<void> initAppImpl() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (io.Platform.isAndroid) {
    await initServerImpl();
  } else {
    throw UnsupportedError('Unsupported platform ${io.Platform.operatingSystem}');
  }
  // REMOVE
//  serverAddress = "http://192.168.1.19:8000?address=http://localhost:8640";
}

const platform = const MethodChannel('anywherelan');
var serverRunning = false; // REMOVE

Future<void> initServerImpl() async {
  assert(!serverRunning, "calling initServer to running server");

  try {
    final int port = await platform.invokeMethod('start_server');
    serverAddress = "http://127.0.0.1:$port";
    serverRunning = true;
  } on PlatformException catch (e) {
    print("Failed to init server: '${e.message}'.");
  } on MissingPluginException catch (e) {
    print("Failed to init server: '${e.message}'.");
  }
}

Future<void> stopServerImpl() async {
  assert(serverRunning, "calling stopServer to not running server");

  try {
    await platform.invokeMethod('stop_server');
  } on PlatformException catch (e) {
    print("Failed to stop server: '${e.message}'.");
  }
  serverRunning = false;
}

bool isServerRunningImpl() {
  return serverRunning;
}

Future<String> importConfigImpl(String config) async {
  assert(!serverRunning, "calling importConfig to running server");

  try {
    await platform.invokeMethod('import_config', {'config': config});
  } on PlatformException catch (e) {
    print("Failed to import server config: '${e.message}'.");
    return e.message == null ? "" : e.message!;
  }

  return "";
}
