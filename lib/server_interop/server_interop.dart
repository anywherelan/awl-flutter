import 'server_interop_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'package:anywherelan/server_interop/server_interop_mobile.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'package:anywherelan/server_interop/server_interop_web.dart';

Future<String> initApp() async {
  return initAppImpl();
}

Future<String> initServer() async {
  return initServerImpl();
}

Future<void> stopServer() async {
  return stopServerImpl();
}

bool isServerRunning() {
  return isServerRunningImpl();
}

/// Reads whether the backend runs from the platform instead of trusting the
/// last start or stop made from the app: on Android it also starts and stops
/// without the app (Always-on VPN, the VPN being revoked). Returns true when the
/// running state changed.
Future<bool> syncServerState() async {
  return syncServerStateImpl();
}

/// Always-on VPN as set for this app in the Android VPN settings. Android only
/// reports it to a running VPN service, so both are false while awl is stopped.
class AlwaysOnStatus {
  final bool alwaysOn;
  final bool lockdown;

  /// Whether the VPN routes all traffic (gateway client mode). Without it awl
  /// routes only its own network, so with lockdown only peers are reachable.
  final bool routesAllTraffic;

  const AlwaysOnStatus({required this.alwaysOn, required this.lockdown, this.routesAllTraffic = false});
}

Future<AlwaysOnStatus> alwaysOnStatus() async {
  return alwaysOnStatusImpl();
}

/// Opens the Android VPN settings, where Always-on VPN is turned on. Returns ""
/// on success or an error string.
Future<String> openVpnSettings() async {
  return openVpnSettingsImpl();
}

Future<String> importConfig(String config) async {
  return importConfigImpl(config);
}

/// Re-applies the VPN routing to match the current backend config (e.g. after
/// toggling gateway client mode). On Android this re-establishes the VPN
/// interface and hot-swaps the new tun fd into the backend without dropping P2P
/// connections; on other platforms it is a no-op. Returns "" on success or an
/// error string.
Future<String> reconfigureVpn() async {
  return reconfigureVpnImpl();
}
