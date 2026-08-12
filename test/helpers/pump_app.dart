import 'package:anywherelan/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a widget inside a `MaterialApp` configured with the same theme as
/// the production app, so widget tests render with realistic styling.
///
/// Optional [size] sets the test view's physical size before pumping —
/// useful for testing responsive layouts.
///
/// [overrides] wraps the app in a `ProviderScope`, for the adapter tests that
/// have providers as their subject — a test named after a `*View` should never
/// need it. With none the tree stays exactly as it was, so screenshots do not
/// shift. [routes] gives a test somewhere to navigate to.
Future<void> pumpAppWidget(
  WidgetTester tester,
  Widget child, {
  Size? size,
  List<Override> overrides = const [],
  Map<String, WidgetBuilder> routes = const {},
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
  Widget app = MaterialApp(
    theme: buildAppTheme(),
    // Off so screenshot tests aren't dominated by the debug ribbon.
    debugShowCheckedModeBanner: false,
    routes: routes,
    home: Scaffold(body: child),
  );
  if (overrides.isNotEmpty) {
    app = ProviderScope(overrides: overrides, child: app);
  }
  await tester.pumpWidget(app);
}

/// Pumps a button and taps it, so that [open] runs with a `BuildContext` that
/// has a `Navigator` over it.
///
/// A dialog has to be opened as a real route to be itself: the route is what
/// supplies its insets and its `IntrinsicWidth`, what `Cancel` pops, and what
/// makes a second opening a fresh `State` rather than the same one. Pumping the
/// dialog widget straight into the body tests none of that.
///
/// The button stays an `ElevatedButton` labelled "open" because screenshots
/// catch it behind the barrier — changing it would invalidate every golden.
Future<void> pumpDialogOpener(
  WidgetTester tester,
  void Function(BuildContext) open, {
  Size? size,
  List<Override> overrides = const [],
  Map<String, WidgetBuilder> routes = const {},

  /// Left to the caller when the dialog is opened with something still in
  /// flight, so it can decide what to wait for.
  bool settle = true,
}) async {
  await pumpAppWidget(
    tester,
    Builder(
      builder: (context) => ElevatedButton(onPressed: () => open(context), child: const Text('open')),
    ),
    size: size,
    overrides: overrides,
    routes: routes,
  );
  await tester.tap(find.text('open'));
  if (settle) await tester.pumpAndSettle();
}
