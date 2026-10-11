import 'package:anywherelan/blocked_peers_screen.dart';
import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/samples.dart';

/// The strings the blocked peers screen states a row in. Plain functions of a
/// [BlockedPeer] and a clock, so they are checked here rather than through a
/// pumped widget.
void main() {
  // Local time, not UTC: the function resolves to a wall clock, and a UTC
  // instant would render differently depending on the machine's timezone.
  final now = DateTime(2026, 4, 10, 9);

  test('the date keeps its clock only while it tells two entries apart', () {
    expect(blockedSinceText(DateTime(2026, 4, 10, 8, 41), now: now), 'blocked today at 08:41');
    expect(blockedSinceText(DateTime(2026, 4, 9, 19, 2), now: now), 'blocked yesterday at 19:02');
    expect(blockedSinceText(DateTime(2026, 1, 18, 16, 13), now: now), 'blocked 18 Jan');
    expect(blockedSinceText(DateTime(2023, 9, 17, 20, 17), now: now), 'blocked 17 Sep 2023');
  });

  test('an entry without a date says nothing rather than "1 Jan 1"', () {
    expect(blockedSinceText(zeroGoTime, now: now), '');
  });

  test('a name of nothing but whitespace is no name', () {
    expect(blockedPeerName(BlockedPeer(otherPeerID, '  old laptop ', now)), 'old laptop');
    expect(blockedPeerName(BlockedPeer(otherPeerID, ' \n', now)), '');
  });
}
