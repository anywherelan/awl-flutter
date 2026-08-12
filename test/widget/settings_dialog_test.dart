import 'package:anywherelan/status_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/load_fonts.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

void main() {
  setUpAll(loadTestFonts);

  const desktopSize = dialogSize;

  /// Stand-in for `_BeGatewaySwitch`, which is injected rather than built here
  /// precisely because it applies its own state through its own endpoint. What
  /// this view owes it is a place in the layout, and that is what is checked.
  const gatewayTile = ListTile(key: Key('gatewayTile'), title: Text('Serve as VPN Gateway'));

  /// Pumps the view and returns the names it submitted, in order.
  Future<List<String>> pumpDialog(
    WidgetTester tester, {
    String initialName = 'my-laptop',
    String error = '',
    Widget? tile = gatewayTile,
    VoidCallback? onDone,
  }) async {
    final saved = <String>[];
    await pumpAppWidget(
      tester,
      SettingsDialogView(
        initialName: initialName,
        gatewayTile: tile,
        onDone: onDone,
        onSubmit: (name) async {
          saved.add(name);
          return error;
        },
      ),
      size: desktopSize,
    );
    await tester.pumpAndSettle();
    return saved;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the current device name', (tester) async {
    await pumpDialog(tester);

    expect(find.widgetWithText(TextFormField, 'my-laptop'), findsOneWidget);
  });

  testWidgets('Save submits the edited name and closes', (tester) async {
    var done = false;
    final saved = await pumpDialog(tester, onDone: () => done = true);

    await tester.enterText(find.byType(TextFormField), 'kitchen-pi');
    await tapSave(tester);

    expect(saved, ['kitchen-pi']);
    expect(done, isTrue);
  });

  testWidgets('an empty name is refused before anything is sent', (tester) async {
    final saved = await pumpDialog(tester);

    await tester.enterText(find.byType(TextFormField), '');
    await tapSave(tester);

    expect(saved, isEmpty);
    expect(find.text('Please enter peer name'), findsOneWidget);
  });

  testWidgets('a rejected save keeps the dialog open and says why', (tester) async {
    var done = false;
    await pumpDialog(tester, error: 'name is already taken', onDone: () => done = true);

    await tapSave(tester);

    expect(done, isFalse);
    expect(find.textContaining('name is already taken'), findsOneWidget);
  });

  testWidgets('the gateway row is rendered where it was handed in', (tester) async {
    await pumpDialog(tester);

    expect(find.byKey(const Key('gatewayTile')), findsOneWidget);
  });

  testWidgets('and is simply absent when there is none', (tester) async {
    // Web has no VPN to serve, so the adapter passes nothing rather than a
    // disabled row.
    await pumpDialog(tester, tile: null);

    expect(find.byKey(const Key('gatewayTile')), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Cancel closes without saving', (tester) async {
    // Opened as a real route: Cancel pops the dialog directly, which needs one
    // to pop.
    final saved = <String>[];
    await pumpAppWidget(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => SettingsDialogView(
              initialName: 'my-laptop',
              onSubmit: (name) async {
                saved.add(name);
                return '';
              },
            ),
          ),
          child: const Text('open'),
        ),
      ),
      size: desktopSize,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
