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

MyPeerInfo _withBootstrap(MyPeerInfo base, int connected) {
  return MyPeerInfo(
    base.peerID,
    base.name,
    base.uptime,
    base.serverVersion,
    base.networkStats,
    base.totalBootstrapPeers,
    connected,
    base.reachability,
    base.awlDNSAddress,
    base.isAwlDNSSetAsSystem,
    base.socks5,
  );
}

void main() {
  // Use a wide test view so the layout doesn't overflow narrow defaults.
  const desktopSize = Size(1200, 900);

  group('StatusPageView', () {
    testWidgets('renders an empty container when peerInfo is null', (tester) async {
      await pumpAppWidget(tester, const StatusPageView(peerInfo: null), size: desktopSize);

      // None of the populated-state strings should appear.
      expect(find.text('Network'), findsNothing);
      expect(find.text('SOCKS5 proxy'), findsNothing);
    });

    testWidgets('renders device header, cards, and key fields from fixture', (tester) async {
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: _loadInfo(),
          proxiesData: _loadProxies(),
          onShowQR: () async {},
          onShowSettings: () async {},
        ),
        size: desktopSize,
      );

      // Device header: name from fixture.
      expect(find.text('myawesomelaptop'), findsOneWidget);

      // Card titles.
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('SOCKS5 proxy'), findsOneWidget);

      // Body labels.
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Reachability'), findsOneWidget);
      expect(find.text('Discovery nodes'), findsOneWidget);

      // Bootstrap value uses "connected / total" — fixture has 4/5 (healthy, no warning).
      expect(find.text('4 / 5'), findsOneWidget);

      // SOCKS5 listener is enabled in the fixture, so the address row appears.
      expect(find.text('Address'), findsOneWidget);
      expect(find.textContaining('127.0.0.66:8080'), findsOneWidget);

      // SOCKS5 active state.
      expect(find.text('Active'), findsOneWidget);

      // Exit peer label and current selection.
      expect(find.text('Exit through'), findsOneWidget);
      expect(find.text('awl-tester'), findsOneWidget);

      // Reachability is "Unknown" in the fixture.
      expect(find.text('Unknown'), findsOneWidget);

      // Header actions are IconButtons surfaced by tooltip.
      expect(find.byTooltip('My ID'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets('My ID button invokes onShowQR', (tester) async {
      var qrCalls = 0;
      await pumpAppWidget(
        tester,
        StatusPageView(peerInfo: _loadInfo(), proxiesData: _loadProxies(), onShowQR: () async => qrCalls++),
        size: desktopSize,
      );

      await tester.tap(find.byTooltip('My ID'));
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

      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();

      expect(settingsCalls, 1);
    });

    testWidgets('Discovery nodes value is highlighted with a warning when low', (tester) async {
      final base = _loadInfo();
      await pumpAppWidget(
        tester,
        StatusPageView(peerInfo: _withBootstrap(base, 0), proxiesData: _loadProxies()),
        size: desktopSize,
      );

      // 0 connected → warning icon + "0 / 5" text.
      expect(find.text('0 / 5'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Discovery nodes value with 1 connected still renders warning', (tester) async {
      final base = _loadInfo();
      await pumpAppWidget(
        tester,
        StatusPageView(peerInfo: _withBootstrap(base, 1), proxiesData: _loadProxies()),
        size: desktopSize,
      );

      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
