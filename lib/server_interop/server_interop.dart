import 'server_interop_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'package:anywherelan/server_interop/server_interop_mobile.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'package:anywherelan/server_interop/server_interop_web.dart';

import 'vpn_app_filter.dart';

export 'vpn_app_filter.dart';

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

/// Launcher-visible apps for the per-app VPN filter picker (Android only).
Future<List<VpnAppEntry>> getInstalledApps() async {
  return getInstalledAppsImpl();
}

/// The current per-app VPN filter state (Android only).
Future<VpnAppFilterState> getAppFilter() async {
  return getAppFilterImpl();
}

/// Persists the per-app VPN filter. Returns "" on success, "restart_required"
/// when a live VPN interface means the caller must restart the server for the
/// filter to take effect, or an error string.
Future<String> setAppFilter(String mode, List<String> packages) async {
  return setAppFilterImpl(mode, packages);
}
