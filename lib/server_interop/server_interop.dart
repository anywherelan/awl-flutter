import 'server_interop_stub.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) 'package:peerlanflutter/server_interop/server_interop_mobile.dart'
// ignore: uri_does_not_exist
    if (dart.library.html) 'package:peerlanflutter/server_interop/server_interop_web.dart';

Future<void> initApp() async {
  return initAppImpl();
}

Future<void> initServer() async {
  return initServerImpl();
}

Future<void> stopServer() async {
  return stopServerImpl();
}

Future<String> importConfig(String config) async {
  return importConfigImpl(config);
}
