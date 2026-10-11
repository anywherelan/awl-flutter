/// Screenshot ("golden") tests for the blocked peers screen.
///
/// Pixel comparisons — see the note at the top of
/// `invite_flow_golden_test.dart` on re-shooting them and on reading a CI
/// mismatch.
@Tags(['golden'])
library;

import 'package:anywherelan/blocked_peers_screen.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/golden.dart';
import '../helpers/load_fonts.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

/// Local wall clock, and every date below a literal rather than an offset from
/// it: the screen prints local time, so an absolute instant would photograph
/// differently in every timezone.
final _now = DateTime(2026, 4, 10, 9);

/// The ways a row differs from the next one, newest first as the backend
/// returns them: blocked today, yesterday, earlier this year, in another year;
/// a name too long for its line, and no name at all.
List<BlockedPeer> _blockedPeers() => [
  BlockedPeer(otherPeerID, 'office-printer', DateTime(2026, 4, 10, 8, 41)),
  BlockedPeer(
    '12D3KooWMASi45ub7Qe4ZE36UT5G6cU4ud8Fhhe4deS4F3cw9KTA',
    'old laptop',
    DateTime(2026, 4, 9, 19, 2),
  ),
  BlockedPeer(
    '12D3KooWb8dLcukC7edhDQ7cn5d4gEYkbUrMWeWQLGsCmrG6dLaY',
    'a name long enough that it cannot fit beside the button on any screen',
    DateTime(2026, 1, 18, 16, 13),
  ),
  BlockedPeer('12D3KooWyNoVKf58ZTBqNAYT3j5qcdsyuMNmPfYetW5v6JXmj54o', '', DateTime(2023, 9, 17, 20, 17)),
];

/// The app bar and background the screen is actually seen with.
Widget _screen(Widget body) {
  return Scaffold(
    appBar: AppBar(title: const Text('Blocked peers')),
    body: body,
  );
}

void main() {
  setUpAll(loadTestFonts);

  // A phone is where the row is tight: the peer ID wraps, and the button has
  // to keep its place beside a name that does not fit.
  testWidgets('blocked peers list', (tester) async {
    await pumpAppWidget(
      tester,
      _screen(BlockedPeersView(peers: _blockedPeers(), now: _now, onUnblock: (_) async {})),
      size: phoneSize,
    );

    await expectGolden(tester, 'blocked_peers_list');
  });

  // The other claim: on a wide window the list stays a column.
  testWidgets('blocked peers list, wide layout', (tester) async {
    await pumpAppWidget(
      tester,
      _screen(BlockedPeersView(peers: _blockedPeers(), now: _now, onUnblock: (_) async {})),
      // The size the invites list is shot at, so the two columns can be laid
      // side by side.
      size: const Size(900, 1000),
    );

    await expectGolden(tester, 'blocked_peers_list_wide');
  });
}
