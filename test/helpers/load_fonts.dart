import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the real Roboto and Material Icons fonts with the test engine.
///
/// Without this, `flutter test` draws every glyph as a filled rectangle (the
/// built-in FlutterTest font) — fine for layout assertions, useless in a
/// screenshot. The files are taken from the Flutter SDK running the test, so
/// they always match the toolchain that produced the golden.
///
/// Every screenshot test needs it, and so does any widget test whose subject is
/// whether something *fits*: the box glyph is far wider than Roboto, so a
/// width-constrained dialog overflows under it for reasons the app never has.
/// Tests that only look things up by text are better off without it — loading
/// fonts changes text metrics, and with them every layout assertion.
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) {
    fail('FLUTTER_ROOT is not set — screenshot tests must run through `flutter test`');
  }
  final fontsDir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!fontsDir.existsSync()) {
    fail('Material fonts are missing from the SDK cache at ${fontsDir.path}');
  }

  // Roboto is what Material picks as the default family on the test platform,
  // so registering it under that name is enough — no theme change needed. The
  // three weights cover the app's titles (w500) and emphasis (w700).
  await _load('Roboto', [
    '${fontsDir.path}/Roboto-Regular.ttf',
    '${fontsDir.path}/Roboto-Medium.ttf',
    '${fontsDir.path}/Roboto-Bold.ttf',
  ]);
  await _load('MaterialIcons', ['${fontsDir.path}/MaterialIcons-Regular.otf']);
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
