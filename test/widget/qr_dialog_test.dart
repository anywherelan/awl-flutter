import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/invite_link.dart';
import 'package:anywherelan/qr_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/load_fonts.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

const _myPeerID = samplePeerID;
const _peerPeerID = otherPeerID;

/// A moment the fixture invites below are measured against, so "expires in …"
/// reads the same on every run.
final _now = sampleNow;

Invite _quickInvite({
  String label = quickQRInviteLabel,
  String status = inviteStatusActive,
  int maxUses = 1,
  int usedCount = 0,
  String token = 'Sqntji_DUou1iZnq5DSlSg',
}) {
  return makeInvite(
    label: label,
    link: 'awl://invite?p=$_myPeerID&t=$token&n=my-laptop',
    maxUses: maxUses,
    usedCount: usedCount,
    expiresAt: _now.add(const Duration(hours: 12)),
    status: status,
  );
}

void main() {
  setUpAll(loadTestFonts);

  const desktopSize = dialogSize;

  /// The link as a dialog currently renders it — the one value it builds and
  /// hands to the field, the Share button and the QR code alike. `QrImageView`
  /// keeps its payload private, so that the code carries this same string is
  /// covered by the copy test rather than read back off the image.
  String shownLink(WidgetTester tester) => tester.widget<LinkSharePanel>(find.byType(LinkSharePanel)).link;

  /// Captures what reaches the clipboard. The dialogs copy through the
  /// platform channel, which is not wired up under test.
  String? Function() mockClipboard(WidgetTester tester) {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return () => copied;
  }

  /// Lets the copy tick ("✓" in place of the copy icon) time out, so the test
  /// does not end with its timer still pending.
  Future<void> settleCopyTick(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

  /// The link field's copy button. Copying is a button of its own, not a tap on
  /// the field — the field's text stays selectable, which is the only working
  /// way to copy on the plain-HTTP web build.
  final copyLink = find.descendant(
    of: find.byType(LinkSharePanel),
    matching: find.byIcon(Icons.content_copy),
  );

  group('showPeerQRDialog', () {
    Future<void> openDialog(WidgetTester tester, String peerID, String peerName) {
      return pumpDialogOpener(
        tester,
        (context) => showPeerQRDialog(context, peerID, peerName),
        size: desktopSize,
      );
    }

    testWidgets('shares a link for a peer from the list, under its display name', (tester) async {
      await openDialog(tester, _peerPeerID, 'vasya-laptop');

      final parsed = parseInviteLink(shownLink(tester));
      expect(parsed.peerID, _peerPeerID);
      expect(parsed.name, 'vasya-laptop');
      expect(parsed.token, isEmpty);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('offers no one-time link: the token would not be ours to give', (tester) async {
      await openDialog(tester, _peerPeerID, 'vasya-laptop');

      expect(find.byType(SegmentedButton<QRMode>), findsNothing);
      expect(find.textContaining('One-time'), findsNothing);
    });

    testWidgets('copies the link, and the peer id separately', (tester) async {
      final copied = mockClipboard(tester);
      await openDialog(tester, _peerPeerID, 'vasya-laptop');

      await tester.tap(copyLink);
      await tester.pump();
      expect(copied(), shownLink(tester));
      expect(find.text('Link copied to clipboard'), findsOneWidget);
      await settleCopyTick(tester);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(CopyableField, 'Peer ID'),
          matching: find.byIcon(Icons.content_copy),
        ),
      );
      await tester.pump();
      expect(copied(), _peerPeerID);
      await settleCopyTick(tester);
    });

    testWidgets('keeps the bare peer id around for typing in by hand', (tester) async {
      await openDialog(tester, _peerPeerID, 'vasya-laptop');

      expect(find.widgetWithText(CopyableField, _peerPeerID), findsOneWidget);
    });

    testWidgets('says the request still has to be accepted', (tester) async {
      await openDialog(tester, _peerPeerID, 'vasya-laptop');

      expect(find.textContaining('still has to be accepted'), findsOneWidget);
      expect(find.textContaining('without your approval'), findsNothing);
    });
  });

  group('MyQRDialogView', () {
    /// Pumps the view with a stubbed quick-link call and reports how many times
    /// it was asked for one.
    Future<int Function()> openView(
      WidgetTester tester, {
      QuickLinkResult Function()? quickLink,
      Duration delay = Duration.zero,
      Size size = desktopSize,
      VoidCallback? onManageLinks,
    }) async {
      var calls = 0;
      await pumpAppWidget(
        tester,
        MyQRDialogView(
          peerID: _myPeerID,
          peerName: 'my-laptop',
          now: _now,
          onManageLinks: onManageLinks ?? () {},
          onQuickLink: () async {
            calls++;
            if (delay > Duration.zero) await Future<void>.delayed(delay);
            return quickLink?.call() ?? QuickLinkResult(invite: _quickInvite());
          },
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      return () => calls;
    }

    Future<void> switchToOneTime(WidgetTester tester) async {
      await tester.tap(find.text('One-time link'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on our own token-less link', (tester) async {
      await openView(tester);

      final parsed = parseInviteLink(shownLink(tester));
      expect(parsed.peerID, _myPeerID);
      expect(parsed.name, 'my-laptop');
      expect(parsed.token, isEmpty);
      expect(find.textContaining('still has to be accepted'), findsOneWidget);
    });

    testWidgets('never opens on the one-time link, whatever was shown last time', (tester) async {
      // The two links look alike and mean very different things, so the
      // dangerous one is always a deliberate choice, never a remembered state.
      // Opened as a route and closed again, the way the dialog is really used
      // — a re-pump would hand the same State back and prove nothing.
      await pumpDialogOpener(
        tester,
        (context) => showDialog<void>(
          context: context,
          builder: (_) => MyQRDialogView(
            peerID: _myPeerID,
            peerName: 'my-laptop',
            now: _now,
            onManageLinks: () {},
            onQuickLink: () async => QuickLinkResult(invite: _quickInvite()),
          ),
        ),
        size: desktopSize,
      );

      await switchToOneTime(tester);
      expect(parseInviteLink(shownLink(tester)).token, isNotEmpty);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(parseInviteLink(shownLink(tester)).token, isEmpty);
    });

    testWidgets('switching to one-time shows the invite link and its terms', (tester) async {
      await openView(tester);
      await switchToOneTime(tester);

      expect(shownLink(tester), _quickInvite().link);
      expect(find.textContaining('without your approval'), findsOneWidget);
      expect(find.textContaining('expires in 12h'), findsOneWidget);
      expect(find.textContaining('still has to be accepted'), findsNothing);
    });

    testWidgets('switching back shows our plain id again', (tester) async {
      await openView(tester);
      await switchToOneTime(tester);

      await tester.tap(find.text('My ID'));
      await tester.pumpAndSettle();

      expect(parseInviteLink(shownLink(tester)).token, isEmpty);
      expect(find.textContaining('without your approval'), findsNothing);
    });

    testWidgets('asks for the link once, however often the mode is flipped', (tester) async {
      final calls = await openView(tester);
      await switchToOneTime(tester);
      await tester.tap(find.text('My ID'));
      await tester.pumpAndSettle();
      await switchToOneTime(tester);

      expect(calls(), 1);
    });

    testWidgets('a second tap before the first answers creates nothing extra', (tester) async {
      final calls = await openView(tester, delay: const Duration(milliseconds: 50));

      await tester.tap(find.text('One-time link'));
      await tester.pump();
      await tester.tap(find.text('One-time link'));
      await tester.pumpAndSettle();

      expect(calls(), 1);
    });

    testWidgets('a failure falls back to the safe mode and says why', (tester) async {
      await openView(
        tester,
        quickLink: () => const QuickLinkResult(error: 'Failed to createInvite: connection refused'),
      );
      await switchToOneTime(tester);

      expect(find.text('Failed to createInvite: connection refused'), findsOneWidget);
      expect(parseInviteLink(shownLink(tester)).token, isEmpty);
      expect(find.textContaining('still has to be accepted'), findsOneWidget);
    });

    testWidgets('copies the one-time link once it is the one on screen', (tester) async {
      final copied = mockClipboard(tester);
      await openView(tester);
      await switchToOneTime(tester);

      await tester.tap(copyLink);
      await tester.pump();

      expect(copied(), _quickInvite().link);
      expect(find.text('Invite link copied to clipboard'), findsOneWidget);
      await settleCopyTick(tester);
    });

    testWidgets('says in its title which of the two links is on screen', (tester) async {
      // The modes differ by a token inside a long string and by the colour of a
      // note. The title is the largest thing here and the only part that
      // survives into a screenshot passed on to someone else.
      await openView(tester);
      expect(find.text('Your link'), findsOneWidget);
      expect(find.text('One-time invite link'), findsNothing);

      await switchToOneTime(tester);
      expect(find.text('One-time invite link'), findsOneWidget);
      expect(find.text('Your link'), findsNothing);
    });

    testWidgets('Manage links hands the user over to the invites screen', (tester) async {
      var managed = false;
      await openView(tester, onManageLinks: () => managed = true);

      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Manage links')));
      await tester.pumpAndSettle();

      expect(managed, isTrue);
    });

    testWidgets('keeps Manage links in the action row, not at the end of the content', (tester) async {
      // Where it used to be, and on every phone-sized viewport that put it
      // below the fold of a scroll view with no scrollbar. `actions:` is an
      // `OverflowBar`, so at large text scales it stacks instead of overflowing.
      await openView(tester);

      expect(
        find.descendant(
          of: find.byType(OverflowBar),
          matching: find.widgetWithText(TextButton, 'Manage links'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('fits a phone in landscape, where the QR code alone would not', (tester) async {
      // The code is 320px tall on a desktop and the dialog holds three more
      // blocks; without `scrollable` this overflowed by 300px.
      await openView(tester, size: phoneLandscapeSize);
      await switchToOneTime(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
