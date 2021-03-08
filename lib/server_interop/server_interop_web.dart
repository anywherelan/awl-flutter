import 'dart:html';
import 'package:peerlanflutter/api.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;

Future<void> initAppImpl() async {
  if (kDebugMode) {
    // REMOVE ?
    serverAddress = "http://192.168.1.19:8000?address=http://localhost:8640";
  } else {
    serverAddress = window.location.origin;
  }
}

Future<void> initServerImpl() async {
  throw UnsupportedError('Unsupported for web');
}

Future<void> stopServerImpl() async {
  throw UnsupportedError('Unsupported for web');
}

Future<String> importConfigImpl(String config) async {
  throw UnsupportedError('Unsupported for web');
}
