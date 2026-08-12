import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// Shoots the whole app, not the widget under test: a screenshot is only worth
/// comparing if it shows what the user sees, including the scaffold around it.
///
/// The path is relative to the *test file's* directory, so callers have to live
/// in `test/golden/`.
Future<void> expectGolden(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

/// Opens [open] as a real dialog route and shoots the whole screen: dialogs are
/// laid out by the route (padding, `IntrinsicWidth`), so a screenshot of their
/// contents alone would not be what the user sees.
Future<void> goldenOfDialog(
  WidgetTester tester,
  Size size,
  String name,
  void Function(BuildContext) open, {

  /// Driven before the shot, for a dialog whose interesting state is one
  /// interaction in.
  Future<void> Function(WidgetTester)? afterOpen,
}) async {
  await pumpDialogOpener(tester, open, size: size, settle: afterOpen != null);
  if (afterOpen != null) await afterOpen(tester);
  await expectGolden(tester, name);
}
