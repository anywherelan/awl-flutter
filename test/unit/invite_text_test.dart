import 'package:anywherelan/entities.dart';
import 'package:anywherelan/invites_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/samples.dart';

/// The strings the invites screen states its list in. They live in
/// `invites_screen.dart` next to the widgets that show them, but they are plain
/// functions of an [Invite] and a clock, so they are checked here rather than
/// through a pumped widget — the assertions are about wording and rounding, and
/// a widget tree would only stand between the two.
void main() {
  // Local time, not UTC: these functions resolve to a wall clock, and a UTC
  // instant would render differently depending on the machine's timezone.
  final now = DateTime(2026, 4, 10, 9);

  group('what a link is called and how much of it is left', () {
    test('an unlabelled link is described rather than identified by its id', () {
      expect(inviteTitle(makeInvite()), 'Single-use link');
      expect(inviteTitle(makeInvite(maxUses: 5)), 'Link for up to 5 devices');
      expect(inviteTitle(makeInvite(label: 'office')), 'office');
    });

    test('the use count is stated only where the pill does not imply it', () {
      // A single-use link the pill already answers for: Active can only mean
      // unused, Used up says it outright.
      expect(inviteUsageText(makeInvite()), '');
      expect(inviteUsageText(makeInvite(usedCount: 1, status: inviteStatusUsedUp)), '');
      // Expired and revoked imply nothing — the link may or may not have been
      // redeemed before it died, and this line is the only place that says so.
      expect(inviteUsageText(makeInvite(status: inviteStatusExpired)), 'not used');
      expect(inviteUsageText(makeInvite(status: inviteStatusRevoked)), 'not used');
      expect(inviteUsageText(makeInvite(usedCount: 1, status: inviteStatusRevoked)), 'used');
      // A multi-use count is always real information.
      expect(inviteUsageText(makeInvite(maxUses: 5, usedCount: 2)), '2 of 5 used');
      expect(
        inviteUsageText(makeInvite(maxUses: 2, usedCount: 2, status: inviteStatusUsedUp)),
        '2 of 2 used',
      );
    });

    test('a dead link states when it ended, where that is knowable', () {
      final expired = makeInvite(
        status: inviteStatusExpired,
        expiresAt: DateTime(2026, 4, 8, 14, 20),
        createdAt: DateTime(2026, 4, 7, 9),
      );
      expect(inviteEndedText(expired, now: now), 'expired 8 Apr');
      expect(
        inviteEndedText(
          makeInvite(status: inviteStatusExpired, expiresAt: now.subtract(const Duration(hours: 2))),
          now: now,
        ),
        'expired today at 07:00',
      );

      // Revoked carries no timestamp in the backend contract, and its
      // ExpiresAt would tell a competing story of how the link ended.
      expect(
        inviteEndedText(
          makeInvite(status: inviteStatusRevoked, expiresAt: DateTime(2026, 4, 8, 14, 20)),
          now: now,
        ),
        '',
      );
      expect(inviteEndedText(makeInvite(maxUses: 2, usedCount: 2, status: inviteStatusUsedUp), now: now), '');
      expect(inviteEndedText(makeInvite(), now: now), '');
    });

    test('time left is relative under a day and a date beyond it', () {
      expect(inviteExpiryText(makeInvite(), now: now), 'never expires');
      expect(
        inviteExpiryText(makeInvite(expiresAt: now.add(const Duration(minutes: 12))), now: now),
        'expires in 12 min',
      );
      expect(
        inviteExpiryText(makeInvite(expiresAt: now.add(const Duration(hours: 20, minutes: 24))), now: now),
        'expires in 20h',
      );
      expect(
        inviteExpiryText(makeInvite(expiresAt: now.add(const Duration(days: 2))), now: now),
        'expires 12 Apr 2026, 09:00',
      );
      expect(
        inviteExpiryText(makeInvite(expiresAt: now.subtract(const Duration(minutes: 1))), now: now),
        'expired',
      );
    });

    test('only the last hour of a link counts as expiring soon', () {
      expect(
        inviteExpiresSoon(makeInvite(expiresAt: now.add(const Duration(minutes: 59))), now: now),
        isTrue,
      );
      expect(inviteExpiresSoon(makeInvite(expiresAt: now.add(const Duration(hours: 2))), now: now), isFalse);
      expect(inviteExpiresSoon(makeInvite(), now: now), isFalse);
      // A dead link is not urgent, whatever its timestamp says.
      expect(
        inviteExpiresSoon(
          makeInvite(expiresAt: now.add(const Duration(minutes: 10)), status: inviteStatusRevoked),
          now: now,
        ),
        isFalse,
      );
    });

    test('creation reads as a time today and a date further back', () {
      expect(inviteCreatedText(DateTime(2026, 4, 10, 8, 24), now: now), 'created today at 08:24');
      expect(inviteCreatedText(DateTime(2026, 4, 9, 19, 2), now: now), 'created yesterday at 19:02');
      expect(inviteCreatedText(DateTime(2026, 4, 4, 19, 2), now: now), 'created 4 Apr');
      expect(inviteCreatedText(DateTime(2025, 12, 31, 23, 59), now: now), 'created 31 Dec 2025');
    });
  });

  group('what the create form promises', () {
    test('resolves a duration to today, tomorrow or a spelled-out date', () {
      expect(inviteExpiresAtText(1200, now: now), 'today at 09:20');
      expect(inviteExpiresAtText(86400, now: now), 'tomorrow at 09:00');
      // Prose, not the ISO form: this string is read inside a sentence.
      expect(inviteExpiresAtText(604800, now: now), '17 Apr 2026, 09:00');
      expect(inviteExpiresAtText(0, now: now), 'Never expires');
    });

    test('a link with no expiry says what does end it', () {
      expect(
        inviteSummaryText(maxUses: 1, expiresInSeconds: 0, allowUsingAsExitNode: false, now: now),
        'Anyone who has this link can join until it is used up or revoked (one device).',
      );
    });

    test('an unusable count reads as "several devices" rather than a number', () {
      expect(
        inviteSummaryText(maxUses: null, expiresInSeconds: 0, allowUsingAsExitNode: false, now: now),
        contains('several devices'),
      );
    });
  });
}
