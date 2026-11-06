import 'package:anywherelan/server_interop/vpn_app_filter.dart';

Future<String> initAppImpl() async {
  throw UnsupportedError('Unsupported platform');
}

Future<String> initServerImpl() async {
  throw UnsupportedError('Unsupported platform');
}

Future<void> stopServerImpl() async {
  throw UnsupportedError('Unsupported platform');
}

bool isServerRunningImpl() {
  throw UnsupportedError('Unsupported platform');
}

Future<String> importConfigImpl(String config) async {
  throw UnsupportedError('Unsupported platform');
}

Future<String> reconfigureVpnImpl() async {
  throw UnsupportedError('Unsupported platform');
}

Future<List<VpnAppEntry>> getInstalledAppsImpl() async {
  throw UnsupportedError('Unsupported platform');
}

Future<VpnAppFilterState> getAppFilterImpl() async {
  throw UnsupportedError('Unsupported platform');
}

Future<String> setAppFilterImpl(String mode, List<String> packages) async {
  throw UnsupportedError('Unsupported platform');
}
