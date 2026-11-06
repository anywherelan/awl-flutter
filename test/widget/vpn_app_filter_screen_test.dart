/// The per-app VPN filter screen. The platform channel that backs it exists
/// only on Android, so the screen takes its three platform calls as seams and
/// each test supplies fakes.
library;

import 'package:anywherelan/server_interop/vpn_app_filter.dart';
import 'package:anywherelan/vpn_app_filter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  const apps = [VpnAppEntry('org.example.alpha', 'Alpha'), VpnAppEntry('org.example.beta', 'Beta')];

  late String mode;
  late List<String> savedPackages;
  late List<({String mode, List<String> packages})> saves;

  setUp(() {
    mode = 'none';
    savedPackages = [];
    saves = [];
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpAppWidget(
      tester,
      VpnAppFilterScreen(
        loadApps: () async => apps,
        loadState: () async => VpnAppFilterState(mode, savedPackages),
        saveFilter: (m, packages) async {
          saves.add((mode: m, packages: packages));
          return '';
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  group('VpnAppFilterScreen', () {
    testWidgets('lists the apps the platform reports', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.textContaining('Every app uses the VPN'), findsOneWidget);
    });

    testWidgets('the app list is inert while every app uses the VPN', (tester) async {
      await pumpScreen(tester);

      final tile = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Alpha'));
      expect(tile.onChanged, isNull);
    });

    testWidgets('both list modes are on offer, so any app can be picked', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Only selected'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Only checked apps use the VPN'), findsOneWidget);
      final tile = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Alpha'));
      expect(tile.onChanged, isNotNull);
    });

    testWidgets('saving sends the chosen mode and packages', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('All except selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(saves, hasLength(1));
      expect(saves.single.mode, 'denylist');
      expect(saves.single.packages, ['org.example.alpha']);
    });

    testWidgets('an allow list saves as allowlist', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Only selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(saves.single.mode, 'allowlist');
      expect(saves.single.packages, ['org.example.beta']);
    });

    testWidgets('a saved filter is shown when the screen opens', (tester) async {
      mode = 'allowlist';
      savedPackages = ['org.example.beta'];
      await pumpScreen(tester);

      final tile = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Beta'));
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNotNull);
    });
  });
}
