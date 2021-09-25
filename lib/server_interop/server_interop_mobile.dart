import 'dart:io' as io;

import 'package:anywherelan/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String> initAppImpl() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (io.Platform.isAndroid) {
    return await initServerImpl();
  } else {
    throw UnsupportedError('Unsupported platform ${io.Platform.operatingSystem}');
  }
}

const platform = const MethodChannel('anywherelan');
var serverRunning = false;

Future<String> initServerImpl() async {
  assert(!serverRunning, "calling initServer to running server");

  try {
    final String apiAddress = await platform.invokeMethod('start_server');
    serverAddress = "http://$apiAddress";
    serverRunning = true;
  } catch (e) {
    print("Failed to start server: '${e.toString()}'");
    return e.toString();
  }
  return "";
}

Future<void> stopServerImpl() async {
  assert(serverRunning, "calling stopServer to not running server");

  try {
    await platform.invokeMethod('stop_server');
  } catch (e) {
    print("Failed to stop server: '${e.toString()}'.");
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
  } catch (e) {
    print("Failed to import server config: '${e.toString()}'");
    return e.toString();
  }

  return "";
}
