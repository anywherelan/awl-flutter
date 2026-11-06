import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:anywherelan/api.dart';
import 'package:anywherelan/server_interop/vpn_app_filter.dart';
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

Future<void> stopServerImpl() async {
  assert(serverRunning, "calling stopServer to not running server");

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

Future<List<VpnAppEntry>> getInstalledAppsImpl() async {
  if (!io.Platform.isAndroid) return const [];
  final raw = await platform.invokeMethod<List<dynamic>>('get_installed_apps');
  return (raw ?? const <dynamic>[]).map((e) {
    final m = e as Map<Object?, Object?>;
    return VpnAppEntry(m['pkg'] as String, m['label'] as String);
  }).toList();
}

Future<VpnAppFilterState> getAppFilterImpl() async {
  if (!io.Platform.isAndroid) {
    return const VpnAppFilterState("none", []);
  }
  final m = await platform.invokeMethod<Map<Object?, dynamic>>('get_app_filter');
  if (m == null) return const VpnAppFilterState("none", []);
  final packages = (m['packages'] as List<dynamic>? ?? const <dynamic>[]).cast<String>().toList();
  return VpnAppFilterState(m['mode'] as String? ?? "none", packages);
}

Future<String> setAppFilterImpl(String mode, List<String> packages) async {
  if (!io.Platform.isAndroid) return "";
  try {
    // The platform returns "restart_required" when a VPN interface is live:
    // the filter can only be applied by re-establishing, which the host does
    // by restarting the server (see _save in vpn_app_filter_screen.dart).
    final result = await platform.invokeMethod<String>('set_app_filter', {
      "mode": mode,
      "packages": packages,
    });
    return result ?? "";
  } catch (e, s) {
    developer.log('Failed to set app filter', error: e, stackTrace: s, name: 'server_interop');
    return e.toString();
  }
}
