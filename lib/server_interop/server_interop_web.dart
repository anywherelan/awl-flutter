// This file is only imported on the web target via conditional imports in
// `server_interop.dart`.

import 'package:anywherelan/api.dart';
import 'package:anywherelan/server_interop/config.dart' as conf;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:web/web.dart' as web;

Future<String> initAppImpl() async {
  if (kDebugMode) {
    serverAddress = conf.getServerAddress();
  } else {
    serverAddress = web.window.location.origin;
  }
  return "";
}

Future<String> initServerImpl() async {
  throw UnsupportedError('Unsupported for web');
}

Future<void> stopServerImpl() async {
  throw UnsupportedError('Unsupported for web');
}

bool isServerRunningImpl() {
  throw UnsupportedError('Unsupported for web');
}

Future<String> importConfigImpl(String config) async {
  throw UnsupportedError('Unsupported for web');
}
