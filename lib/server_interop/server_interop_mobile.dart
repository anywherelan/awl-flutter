import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:anywherelan/api.dart';
import 'package:anywherelan/server_interop/server_interop.dart' show AlwaysOnStatus;
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

const platform = MethodChannel('anywherelan');
var serverRunning = false;

Future<String> initServerImpl() async {
  assert(!serverRunning, "calling initServer to running server");

  try {
    final String apiAddress = await platform.invokeMethod('start_server');
    serverAddress = "http://$apiAddress";
    serverRunning = true;
  } catch (e, s) {
    developer.log('Failed to start server', error: e, stackTrace: s, name: 'server_interop');
    return e.toString();
  }
  return "";
}

// Safe to call when the server already stopped, e.g. when Android stopped it
// while the app still showed it as running.
Future<void> stopServerImpl() async {
  try {
    await platform.invokeMethod('stop_server');
  } catch (e, s) {
    developer.log('Failed to stop server', error: e, stackTrace: s, name: 'server_interop');
  }
  serverRunning = false;
}

bool isServerRunningImpl() {
  return serverRunning;
}

Future<bool> syncServerStateImpl() async {
  try {
    final String apiAddress = await platform.invokeMethod('server_status');
    final running = apiAddress != "";
    if (running) serverAddress = "http://$apiAddress";
    final changed = running != serverRunning;
    serverRunning = running;
    return changed;
  } catch (e, s) {
    developer.log('Failed to read server status', error: e, stackTrace: s, name: 'server_interop');
    return false;
  }
}

Future<AlwaysOnStatus> alwaysOnStatusImpl() async {
  try {
    final status = await platform.invokeMapMethod<String, bool>('always_on_status');
    return AlwaysOnStatus(
      known: status?['known'] ?? false,
      alwaysOn: status?['alwaysOn'] ?? false,
      lockdown: status?['lockdown'] ?? false,
      routesAllTraffic: status?['routesAllTraffic'] ?? false,
    );
  } catch (e, s) {
    developer.log('Failed to read always-on status', error: e, stackTrace: s, name: 'server_interop');
    return const AlwaysOnStatus(known: false, alwaysOn: false, lockdown: false);
  }
}

Future<String> openVpnSettingsImpl() async {
  try {
    await platform.invokeMethod('open_vpn_settings');
  } catch (e, s) {
    developer.log('Failed to open vpn settings', error: e, stackTrace: s, name: 'server_interop');
    return e.toString();
  }
  return "";
}

Future<String> importConfigImpl(String config) async {
  assert(!serverRunning, "calling importConfig to running server");

  try {
    await platform.invokeMethod('import_config', {'config': config});
  } catch (e, s) {
    developer.log('Failed to import server config', error: e, stackTrace: s, name: 'server_interop');
    return e.toString();
  }

  return "";
}

Future<String> reconfigureVpnImpl() async {
  if (!io.Platform.isAndroid) return "";

  try {
    await platform.invokeMethod('reconfigure_vpn');
  } catch (e, s) {
    developer.log('Failed to reconfigure vpn', error: e, stackTrace: s, name: 'server_interop');
    return e.toString();
  }

  return "";
}
