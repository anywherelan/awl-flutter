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
    base.vpnGateway,
  );
}

MyPeerInfo _withGateway(MyPeerInfo base, VPNGatewayInfo gateway) {
  return MyPeerInfo(
    base.peerID,
    base.name,
    base.uptime,
    base.serverVersion,
    base.networkStats,
    base.totalBootstrapPeers,
    base.connectedBootstrapPeers,
    base.reachability,
    base.awlDNSAddress,
    base.isAwlDNSSetAsSystem,
    base.socks5,
    gateway,
  );
}

MyPeerInfo _withSocks5(MyPeerInfo base, SOCKS5Info socks5) {
  return MyPeerInfo(
    base.peerID,
    base.name,
    base.uptime,
    base.serverVersion,
    base.networkStats,
    base.totalBootstrapPeers,
    base.connectedBootstrapPeers,
    base.reachability,
    base.awlDNSAddress,
    base.isAwlDNSSetAsSystem,
    socks5,
    base.vpnGateway,
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
      expect(find.text('VPN Gateway'), findsOneWidget);
      // Gateway is off in the fixture.
      expect(find.text('Off'), findsOneWidget);

      // Body labels.
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Reachability'), findsOneWidget);
      // Discovery row hidden at full health (fixture: 4/5 connected ≥2).
      // The pill in the header carries the network state instead.
      expect(find.text('Discovery nodes'), findsNothing);
      expect(find.text('Online'), findsOneWidget);

      // SOCKS5 listener is enabled in the fixture, so the address row appears.
      expect(find.text('Address'), findsOneWidget);
      expect(find.textContaining('127.0.0.66:8080'), findsOneWidget);

      // SOCKS5 active state.
      expect(find.text('Active'), findsOneWidget);

      // Exit peer floating label (inside the dropdown's OutlineInputBorder)
      // and the current selection. The outer "Exit through" label was
      // removed — the inner floating label is the only label now, matching
      // the Address field's pattern.
      expect(find.text('Exit peer'), findsAtLeastNWidgets(1));
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

    testWidgets('Gateway card shows empty-state hint when off and no candidates', (tester) async {
      final base = _withGateway(
        _loadInfo(),
        VPNGatewayInfo(false, '', '', false, false, '', Duration.zero, false),
      );
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: base,
          proxiesData: _loadProxies(),
          gatewaysData: ListAvailableVPNGatewaysResponse(const []),
        ),
        size: desktopSize,
      );

      expect(find.text('VPN Gateway'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.textContaining('No devices offer VPN gateway'), findsOneWidget);
      expect(find.textContaining('Or open Settings to become a gateway yourself'), findsOneWidget);
      // Gateway dropdown is hidden in empty state — only the SOCKS5 dropdown renders 'Exit peer'.
      expect(find.text('Exit peer'), findsOneWidget);
    });

    testWidgets('Gateway card shows Active pill and selected exit-node name when connected', (tester) async {
      final base = _withGateway(
        _loadInfo(),
        VPNGatewayInfo(
          true,
          'peer-vasya',
          'vasya-laptop',
          true,
          false,
          '203.0.113.45',
          const Duration(milliseconds: 21),
          false,
        ),
      );
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: base,
          proxiesData: _loadProxies(),
          gatewaysData: ListAvailableVPNGatewaysResponse([
            AvailableVPNGateway('peer-vasya', 'vasya-laptop', true),
          ]),
        ),
        size: desktopSize,
      );

      // Active pill (rendered for both SOCKS5 and Gateway in this fixture).
      expect(find.text('Active'), findsNWidgets(2));
      // Selected name appears once — inside the dropdown trigger only,
      // not duplicated by a separate "Exit node:" line.
      expect(find.text('vasya-laptop'), findsOneWidget);
      expect(find.textContaining('Exit node:'), findsNothing);
    });

    testWidgets('Gateway card shows Connecting pill when enabled but not yet connected', (tester) async {
      final base = _withGateway(
        _loadInfo(),
        VPNGatewayInfo(true, 'peer-vasya', 'vasya-laptop', false, false, '', Duration.zero, false),
      );
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: base,
          proxiesData: _loadProxies(),
          gatewaysData: ListAvailableVPNGatewaysResponse([
            AvailableVPNGateway('peer-vasya', 'vasya-laptop', false),
          ]),
        ),
        size: desktopSize,
      );

      expect(find.text('Connecting…'), findsOneWidget);
    });

    testWidgets('Gateway dropdown picks an exit node and invokes onUpdateGateway', (tester) async {
      final base = _withGateway(
        _loadInfo(),
        VPNGatewayInfo(false, '', '', false, false, '', Duration.zero, false),
      );
      String? receivedPeerID;
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: base,
          proxiesData: _loadProxies(),
          gatewaysData: ListAvailableVPNGatewaysResponse([
            AvailableVPNGateway('peer-vasya', 'vasya-laptop', true),
          ]),
          onUpdateGateway: (id) async {
            receivedPeerID = id;
            return '';
          },
        ),
        size: desktopSize,
      );

      // Open the dropdown (PopupMenuButton on desktop).
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('vasya-laptop').last);
      await tester.pumpAndSettle();

      expect(receivedPeerID, 'peer-vasya');
    });

    testWidgets('Network header shows Online pill at full health (no Discovery row)', (tester) async {
      await pumpAppWidget(
        tester,
        StatusPageView(peerInfo: _withBootstrap(_loadInfo(), 5), proxiesData: _loadProxies()),
        size: desktopSize,
      );

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Discovery nodes'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('Network header shows Offline pill at zero connected', (tester) async {
      await pumpAppWidget(
        tester,
        StatusPageView(peerInfo: _withBootstrap(_loadInfo(), 0), proxiesData: _loadProxies()),
        size: desktopSize,
      );

      expect(find.text('Offline'), findsOneWidget);
      // Discovery row stays visible at low health.
      expect(find.text('Discovery nodes'), findsOneWidget);
    });

    testWidgets('SOCKS5 pill flips to Connecting when SOCKS5Info.connected is false', (tester) async {
      final base = _loadInfo();
      // Override Connected to false; SOCKS5Info.connected is now the source
      // of truth for the pill, not a cross-lookup in proxiesData.
      final socks5 = SOCKS5Info(
        base.socks5.listenAddress,
        base.socks5.proxyingEnabled,
        base.socks5.listenerEnabled,
        false,
        base.socks5.usingPeerID,
        base.socks5.usingPeerName,
        base.socks5.usingPeerPublicIP,
        base.socks5.usingPeerPing,
        base.socks5.usingPeerThroughRelay,
      );
      await pumpAppWidget(
        tester,
        StatusPageView(peerInfo: _withSocks5(base, socks5), proxiesData: _loadProxies()),
        size: desktopSize,
      );

      expect(find.text('Connecting…'), findsOneWidget);
      // The selected name still shows in the dropdown trigger.
      expect(find.text(base.socks5.usingPeerName), findsOneWidget);
    });

    testWidgets('SOCKS5 empty-state hint shows when no candidates and nothing selected', (tester) async {
      final base = _loadInfo();
      // Wipe the upstream selection so we hit the empty-state branch.
      final socks5 = SOCKS5Info(
        base.socks5.listenAddress,
        base.socks5.proxyingEnabled,
        base.socks5.listenerEnabled,
        false,
        '',
        '',
        '',
        Duration.zero,
        false,
      );
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: _withSocks5(base, socks5),
          proxiesData: ListAvailableProxiesResponse(const []),
        ),
        size: desktopSize,
      );

      expect(find.textContaining('every connection will fail'), findsOneWidget);
    });

    testWidgets('Gateway active state renders Direct/ping status line and Public IP row', (tester) async {
      const exitID = 'peer-vasya';
      const exitName = 'vasya-laptop';
      const exitIP = '198.51.100.7';
      var base = _loadInfo();
      // Clear SOCKS5 upstream so its Public IP row doesn't compete with the
      // gateway's in this assertion.
      base = _withSocks5(
        base,
        SOCKS5Info(
          base.socks5.listenAddress,
          base.socks5.proxyingEnabled,
          base.socks5.listenerEnabled,
          false,
          '',
          '',
          '',
          Duration.zero,
          false,
        ),
      );
      base = _withGateway(
        base,
        VPNGatewayInfo(true, exitID, exitName, true, false, exitIP, const Duration(milliseconds: 21), false),
      );
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: base,
          proxiesData: ListAvailableProxiesResponse(const []),
          gatewaysData: ListAvailableVPNGatewaysResponse([AvailableVPNGateway(exitID, exitName, true)]),
        ),
        size: desktopSize,
      );

      // Status line: "Direct · 21 ms".
      expect(find.text('Direct · 21 ms'), findsOneWidget);
      // Public IP row.
      expect(find.text('Public IP: '), findsOneWidget);
      expect(find.text(exitIP), findsOneWidget);
    });

    testWidgets('Gateway via-relay status line renders when no direct connection exists', (tester) async {
      const exitID = 'peer-vasya';
      const exitName = 'vasya-laptop';
      var base = _loadInfo();
      base = _withSocks5(
        base,
        SOCKS5Info(
          base.socks5.listenAddress,
          base.socks5.proxyingEnabled,
          base.socks5.listenerEnabled,
          false,
          '',
          '',
          '',
          Duration.zero,
          false,
        ),
      );
      base = _withGateway(
        base,
        VPNGatewayInfo(true, exitID, exitName, true, false, '', const Duration(milliseconds: 80), true),
      );
      await pumpAppWidget(
        tester,
        StatusPageView(
          peerInfo: base,
          proxiesData: ListAvailableProxiesResponse(const []),
          gatewaysData: ListAvailableVPNGatewaysResponse([AvailableVPNGateway(exitID, exitName, true)]),
        ),
        size: desktopSize,
      );

      expect(find.text('Via relay · 80 ms'), findsOneWidget);
    });
  });
}
