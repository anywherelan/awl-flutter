import 'package:anywherelan/entities.dart';
import 'package:anywherelan/status_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_reader.dart';
import '../helpers/pump_app.dart';

MyPeerInfo _loadInfo() {
  final json = loadFixtureJson('my_peer_info.json') as Map<String, dynamic>;
  return MyPeerInfo.fromJson(json);
}

ListAvailableProxiesResponse _loadProxies() {
  final json = loadFixtureJson('available_proxies.json') as Map<String, dynamic>;
  return ListAvailableProxiesResponse.fromJson(json);
}

void main() {
  // Use a wide test view so the layout doesn't overflow narrow defaults.
  const desktopSize = Size(1200, 900);

  group('StatusPageView', () {
    testWidgets('renders an empty container when peerInfo is null', (tester) async {
      await pumpAppWidget(tester, const StatusPageView(peerInfo: null), size: desktopSize);

      // None of the populated-state strings should appear.
      expect(find.text('NETWORK'), findsNothing);
      expect(find.text('SERVICES'), findsNothing);
    });

    testWidgets('renders device header, sections, and key fields from fixture', (tester) async {
      await pumpAppWidget(
        tester,
        StatusPageView(peerInfo: _loadInfo(), proxiesData: _loadProxies()),
        size: desktopSize,
      );

      // Device header: name from fixture.
      expect(find.text('myawesomelaptop'), findsOneWidget);

      // Section headers.
      expect(find.text('NETWORK'), findsOneWidget);
      expect(find.text('SERVICES'), findsOneWidget);

      // Body labels.
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Reachability'), findsOneWidget);
      expect(find.text('Bootstrap peers'), findsOneWidget);
      expect(find.text('DNS'), findsOneWidget);
      expect(find.text('SOCKS5 Proxy'), findsOneWidget);

      // Bootstrap chip uses "connected/total" — fixture has 4/5.
      expect(find.text('4/5'), findsOneWidget);

      // SOCKS5 listener is enabled in the fixture, so the proxy address row appears.
      expect(find.text('Proxy address'), findsOneWidget);
      expect(find.textContaining('127.0.0.66:8080'), findsOneWidget);

      // Reachability is "Unknown" in the fixture.
      expect(find.text('Unknown'), findsOneWidget);

      // The action buttons render.
      expect(find.text('My ID'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('My ID button invokes onShowQR', (tester) async {
      var qrCalls = 0;
      await pumpAppWidget(
        tester,
        StatusPageView(peerInfo: _loadInfo(), proxiesData: _loadProxies(), onShowQR: () async => qrCalls++),
        size: desktopSize,
      );

      await tester.ensureVisible(find.text('My ID'));
      await tester.tap(find.text('My ID'));
      await tester.pump();

      expect(qrCalls, 1);
    });

    testWidgets('Settings button invokes onShowSettings', (tester) async {
      var settingsCalls = 0;
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: _loadInfo(),
          proxiesData: _loadProxies(),
          onShowSettings: () async => settingsCalls++,
        ),
        size: desktopSize,
      );

      await tester.ensureVisible(find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pump();

      expect(settingsCalls, 1);
    });
  });
}
