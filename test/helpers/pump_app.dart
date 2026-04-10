import 'package:anywherelan/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget inside a `MaterialApp` configured with the same theme as
/// the production app, so widget tests render with realistic styling.
///
/// Optional [size] sets the test view's physical size before pumping —
/// useful for testing responsive layouts.
Future<void> pumpAppWidget(WidgetTester tester, Widget child, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    ),
  );
}
