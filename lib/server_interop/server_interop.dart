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

Future<String> importConfig(String config) async {
  return importConfigImpl(config);
}
