import 'package:anywherelan/common.dart' show zeroGoTime;
import 'package:anywherelan/entities.dart';
import 'package:flutter/material.dart' show Size;

import '../fixtures/fixture_reader.dart';

/// Sample values shared by the tests, so that a peer id, a link or an invite
/// looks the same wherever it turns up — and so that a new field on [Invite]
/// costs one edit here instead of one per test file.

/// This device's peer id. The same one `my_peer_info.json` carries, so a test
/// may mix the fixture and these constants without describing two peers.
const samplePeerID = '12D3KooWPxx4CkH2AL45tzKUR2g6Ht55g82eFuSMevAximtCQfwR';

/// Somebody else — a peer from the list, an incoming friend request. Kept
/// visibly different from [samplePeerID] so that a test asserting on "whose id
/// is this" cannot pass by accident.
const otherPeerID = '12D3KooWKRyzVWW6ChFjQjK4miCty85Niy49tpPV95XdKu1BcvMA';

/// Base64url, like the real thing: the escaping tests depend on it carrying no
/// character that needs escaping.
const sampleToken = 'Xk9vQ2t7bF1sZ0pQd3JmYQ';

/// A full invitation: peer id, token, name.
const sampleInviteLink = 'awl://invite?p=$samplePeerID&t=$sampleToken&n=Alice';

/// The same link without its token — an identity to add by hand, which is what
/// the QR dialogs share. Looks nearly alike and means something else entirely,
/// which is why several tests need both.
const sampleTokenlessLink = 'awl://invite?p=$samplePeerID&n=Alice';

/// An `awl://` link that cannot be used: the peer id is not one.
const sampleBrokenLink = 'awl://invite?p=not-a-peer-id&t=$sampleToken';

/// The moment invites are rendered against, so "expires in …" reads the same on
/// every run. UTC, matching the timestamps in `invites.json`: the distance
/// between two absolute instants is the same in every timezone.
///
/// Not for goldens — an instant *renders* as a different wall clock in each
/// timezone. See `_now` in `test/golden/invite_flow_golden_test.dart`.
final sampleNow = DateTime.utc(2026, 4, 10, 9);

/// Viewport sizes. Named rather than spelled out at each call site, because the
/// number itself never says what it is for — and the wrong one silently changes
/// which layout branch is under test.

/// A phone. Narrow enough that "Create link" is a FAB and the peer badges drop
/// to their own row.
const phoneSize = Size(420, 900);

/// A phone on its side: the case a dialog has to survive by scrolling.
const phoneLandscapeSize = Size(640, 360);

/// Roomy enough for a 450px form dialog with all of its rows unfolded — the
/// default 800x600 view leaves the action row out of a tap's reach.
const dialogSize = Size(900, 1200);

/// Wide layout: side-by-side columns, full-length badge labels, two-column peer
/// details.
const wideSize = Size(1200, 900);

/// Wide and tall, for a full-screen form whose danger zone must be on screen
/// without scrolling.
const tallSize = Size(1200, 1600);

/// The invites fixture as the backend sends it — raw, for tests that feed it
/// back through an HTTP mock or check key names.
List<Map<String, dynamic>> invitesFixtureJson() {
  return (loadFixtureJson('invites.json') as List<dynamic>).cast<Map<String, dynamic>>();
}

/// The invites fixture parsed: one active single-use link, one used-up
/// multi-use link, one revoked one that never expires.
List<Invite> invitesFixture() => invitesFixtureJson().map(Invite.fromJson).toList();

/// One invite, named rather than positional: [Invite] takes eleven positional
/// arguments, most of which any given test does not care about, and a test that
/// spells them all out says nothing about which of them it is actually about.
///
/// Defaults describe the harmless case — a fresh, single-use, unused, active
/// link that never expires.
Invite makeInvite({
  String id = 'inv-1',
  String label = '',
  String link = sampleInviteLink,
  String alias = '',
  bool allowUsingAsExitNode = false,
  int maxUses = 1,
  int usedCount = 0,
  DateTime? expiresAt,
  DateTime? createdAt,
  bool revoked = false,
  String status = inviteStatusActive,
}) {
  return Invite(
    id,
    label,
    link,
    alias,
    allowUsingAsExitNode,
    maxUses,
    usedCount,
    // Go's zero time: never expires.
    expiresAt ?? zeroGoTime,
    createdAt ?? sampleNow,
    revoked,
    status,
  );
}
