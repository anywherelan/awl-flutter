import 'package:anywherelan/entities.dart';
import 'package:anywherelan/peers_list_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_reader.dart';
import '../helpers/pump_app.dart';

List<KnownPeer> _loadPeers() {
  final list = loadFixtureJson('known_peers.json') as List<dynamic>;
  return list.cast<Map<String, dynamic>>().map(KnownPeer.fromJson).toList();
}

void main() {
  const desktopSize = Size(1200, 900);

  group('PeersListView', () {
    testWidgets('shows empty state when peers is null', (tester) async {
      await pumpAppWidget(tester, const PeersListView(peers: null), size: desktopSize);

      expect(find.text('No known peers'), findsOneWidget);
      expect(find.text('Use Add peer to connect to someone'), findsOneWidget);
    });

    testWidgets('shows empty state when peers is empty', (tester) async {
      await pumpAppWidget(tester, const PeersListView(peers: <KnownPeer>[]), size: desktopSize);

      expect(find.text('No known peers'), findsOneWidget);
    });

    testWidgets('renders fixture peers with display name and status summary', (tester) async {
      final peers = _loadPeers();
      await pumpAppWidget(tester, PeersListView(peers: peers), size: desktopSize);

      // Each fixture peer's display name should appear in the list.
      for (final p in peers) {
        expect(find.text(p.displayName), findsOneWidget);
      }

      // Online indicator "<k>/<n> online" — fixture peer is connected+confirmed.
      final onlineCount = peers.where((p) => p.connected && p.confirmed).length;
      expect(find.text('$onlineCount/${peers.length} online'), findsOneWidget);
    });

    testWidgets('expanding a peer reveals action buttons that fire callbacks', (tester) async {
      final peers = _loadPeers();
      KnownPeer? settingsPeer;
      KnownPeer? qrPeer;

      await pumpAppWidget(
        tester,
        PeersListView(
          peers: peers,
          onPeerSettings: (p) async => settingsPeer = p,
          onShowQR: (p) async => qrPeer = p,
        ),
        size: desktopSize,
      );

      // Tap the peer card header to expand it.
      await tester.tap(find.text(peers.first.displayName));
      await tester.pumpAndSettle();

      // The expansion panel reveals Settings + Show ID buttons.
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Show ID'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(settingsPeer, isNotNull);
      expect(settingsPeer!.peerID, peers.first.peerID);

      await tester.tap(find.text('Show ID'));
      await tester.pump();
      expect(qrPeer, isNotNull);
      expect(qrPeer!.peerID, peers.first.peerID);
    });
  });
}
