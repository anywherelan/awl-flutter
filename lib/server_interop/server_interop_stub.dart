import 'package:anywherelan/server_interop/server_interop.dart' show AlwaysOnStatus;

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

Future<bool> syncServerStateImpl() async {
  throw UnsupportedError('Unsupported platform');
}

Future<AlwaysOnStatus> alwaysOnStatusImpl() async {
  throw UnsupportedError('Unsupported platform');
}

Future<String> openVpnSettingsImpl() async {
  throw UnsupportedError('Unsupported platform');
}

Future<String> importConfigImpl(String config) async {
  throw UnsupportedError('Unsupported platform');
}

Future<String> reconfigureVpnImpl() async {
  throw UnsupportedError('Unsupported platform');
}
