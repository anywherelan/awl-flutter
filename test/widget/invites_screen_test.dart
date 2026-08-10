import 'dart:async';

import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/invites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/load_fonts.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

/// Fixed point the fixture's invites are rendered against, so "expires in …"
/// does not drift with the wall clock. The strings themselves are checked in
/// `test/unit/invite_text_test.dart`; here they only have to reach the screen.
final _now = sampleNow;

void main() {
  // The dialogs below are 450px wide by design, and `flutter test` otherwise
  // draws every glyph as a box roughly one em wide — far wider than Roboto,
  // which overflows the two dropdowns in the create form and reports a layout
  // error that does not exist in the app. Real fonts make the metrics honest,
  // so an overflow reported here is a real one.
  setUpAll(loadTestFonts);

  const desktopSize = dialogSize;

  group('InvitesView', () {
    testWidgets('shows a spinner while the list is loading', (tester) async {
      await pumpAppWidget(tester, const InvitesView(invites: null), size: desktopSize);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the error instead of the list', (tester) async {
      await pumpAppWidget(
        tester,
        const InvitesView(invites: <Invite>[], error: 'server unavailable'),
        size: desktopSize,
      );

      expect(find.text('server unavailable'), findsOneWidget);
      expect(find.text('No invite links'), findsNothing);
    });

    testWidgets('empty state offers to create a link', (tester) async {
      var created = 0;
      await pumpAppWidget(
        tester,
        InvitesView(invites: const <Invite>[], onCreate: () async => created++),
        size: desktopSize,
      );

      expect(find.text('No invite links'), findsOneWidget);
      await tester.tap(find.text('Create link'));
      expect(created, 1);
    });

    testWidgets('renders each invite with its title, settings and status', (tester) async {
      await pumpAppWidget(
        tester,
        InvitesView(invites: invitesFixture(), now: _now),
        size: desktopSize,
      );

      expect(find.text('my laptop'), findsOneWidget);
      expect(find.text('friends'), findsOneWidget);
      // No label: what the link is, not the id it is filed under — a list of
      // "Invite c04e" tells the reader nothing.
      expect(find.text('Link for up to 5 devices'), findsOneWidget);

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Used up'), findsOneWidget);
      expect(find.text('Revoked'), findsOneWidget);

      // Settings baked into the link are visible without opening it, and say
      // what they are rather than just naming a value.
      expect(find.text('name "laptop"'), findsOneWidget);
      expect(find.text('exit node allowed'), findsOneWidget);
    });

    testWidgets('the title stays on one line, whatever the label contains', (tester) async {
      final invite = invitesFixture().first;
      final withNewline = makeInvite(
        label: 'x\nActive · 0/1 used',
        expiresAt: invite.expiresAt,
        createdAt: invite.createdAt,
      );

      await pumpAppWidget(
        tester,
        InvitesView(invites: [withNewline], now: _now),
        size: desktopSize,
      );

      // The label is free text; a second line of it in the title's own style
      // would be room for a fake status line under the real title.
      final title = tester.widget<Text>(find.text('x\nActive · 0/1 used'));
      expect(title.maxLines, 1);
    });

    testWidgets('the meta line states what is left of the link and when it was made', (tester) async {
      final invites = invitesFixture();
      await pumpAppWidget(
        tester,
        InvitesView(invites: invites, now: _now),
        size: desktopSize,
      );

      String created(Invite invite) => inviteCreatedText(invite.createdAt, now: _now);

      // Active: coarse time left — the screen does not poll, so a countdown to
      // the minute would be precision it cannot back up. No use count: on a
      // single-use link the pill already says it has not been used.
      expect(find.text('expires in 20h · ${created(invites[0])}', findRichText: true), findsOneWidget);
      // Dead: no countdown, the pill says why it is dead. The count stays,
      // because on a multi-use link it means something.
      expect(find.text('2 of 2 used · ${created(invites[1])}', findRichText: true), findsOneWidget);
      expect(find.text('1 of 5 used · ${created(invites[2])}', findRichText: true), findsOneWidget);
    });

    testWidgets('an expired link says when it ended and whether it was used', (tester) async {
      final expired = makeInvite(
        id: 'a1b2',
        label: 'for the office',
        expiresAt: DateTime.utc(2026, 4, 8, 14, 20),
        createdAt: DateTime.utc(2026, 4, 7, 9),
        status: inviteStatusExpired,
      );

      await pumpAppWidget(
        tester,
        InvitesView(invites: [expired], now: _now),
        size: desktopSize,
      );

      // Without "not used" the row would be a bare creation date: the pill says
      // the link is over, not whether anyone got in through it first.
      expect(
        find.text(
          'not used · ${inviteEndedText(expired, now: _now)} · '
          '${inviteCreatedText(expired.createdAt, now: _now)}',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('only active invites offer actions', (tester) async {
      await pumpAppWidget(
        tester,
        InvitesView(invites: invitesFixture(), now: _now),
        size: desktopSize,
      );

      // Fixture has exactly one active invite out of three.
      expect(find.text('Show link'), findsOneWidget);
      expect(find.text('Revoke link'), findsOneWidget);
    });

    testWidgets('revoke sits on the card, before the primary action', (tester) async {
      Invite? revoked;
      await pumpAppWidget(
        tester,
        InvitesView(invites: invitesFixture(), now: _now, onRevoke: (invite) async => revoked = invite),
        size: desktopSize,
      );

      await tester.tap(find.text('Revoke link'));
      await tester.pumpAndSettle();
      expect(revoked?.id, '9f3a');

      // One action group on the right, laid out like a dialog's: the primary
      // action last, so the destructive one is not the thing at the edge. They
      // are adjacent — confirming is the screen's job (showRevokeInviteDialog)
      // — but not flush against each other.
      final showLink = tester.getRect(find.text('Show link'));
      final revoke = tester.getRect(find.text('Revoke link'));
      expect(revoke.right, lessThan(showLink.left));
      expect(showLink.left - revoke.right, greaterThan(12));
    });

    testWidgets('the status pill sits on the same axis on every card', (tester) async {
      await pumpAppWidget(
        tester,
        InvitesView(invites: invitesFixture(), now: _now),
        size: desktopSize,
      );

      // It used to shift by the width of a menu button that only active cards
      // had, which was visible as a ragged column down the list.
      final rights = tester
          .widgetList<StatusPill>(find.byType(StatusPill))
          .map((pill) => tester.getRect(find.byWidget(pill)).right)
          .toSet();
      expect(rights, hasLength(1));
    });

    testWidgets('Show link fires with the tapped invite', (tester) async {
      Invite? shown;
      await pumpAppWidget(
        tester,
        InvitesView(invites: invitesFixture(), now: _now, onShowLink: (invite) async => shown = invite),
        size: desktopSize,
      );

      await tester.tap(find.text('Show link'));

      expect(shown?.id, '9f3a');
    });
  });

  group('create link placement', () {
    testWidgets('a wide layout puts it in a header above the list', (tester) async {
      var created = 0;
      await pumpAppWidget(
        tester,
        InvitesView(
          invites: invitesFixture(),
          now: _now,
          showCreateInHeader: true,
          onCreate: () async => created++,
        ),
        size: desktopSize,
      );

      await tester.tap(find.text('Create link'));
      expect(created, 1);

      // Above the list, so it stays put while the list scrolls.
      final button = tester.getRect(find.text('Create link'));
      final list = tester.getRect(find.byType(ListView));
      expect(button.bottom, lessThanOrEqualTo(list.top));
    });

    testWidgets('a narrow layout leaves it to the screen, as a FAB', (tester) async {
      await pumpAppWidget(
        tester,
        InvitesView(invites: invitesFixture(), now: _now),
        size: phoneSize,
      );

      expect(find.text('Create link'), findsNothing);
    });

    testWidgets('an empty list keeps its own call to action, and only that', (tester) async {
      await pumpAppWidget(
        tester,
        InvitesView(invites: const <Invite>[], showCreateInHeader: true, onCreate: () async {}),
        size: desktopSize,
      );

      expect(find.text('No invite links'), findsOneWidget);
      expect(find.text('Create link'), findsOneWidget);
    });
  });

  group('CreateInviteDialog', () {
    const usesCount = Key('inviteUsesCount');
    const nameField = 'Name for the new device';

    /// Pumps the form and collects what it submits. [fails] makes every submit
    /// come back rejected, as a server-side validation error would.
    Future<List<CreateInviteRequest>> pumpForm(
      WidgetTester tester, {
      String fails = '',
      VoidCallback? onDone,
    }) async {
      final submitted = <CreateInviteRequest>[];
      await pumpAppWidget(
        tester,
        CreateInviteDialog(
          onSubmit: (request) async {
            submitted.add(request);
            return fails;
          },
          onDone: onDone,
          // A local (not UTC) instant, so the resolved expiry reads the same
          // whatever timezone the test runs in.
          now: DateTime(2026, 4, 10, 9),
        ),
        size: desktopSize,
      );
      return submitted;
    }

    testWidgets('submits the default single-use, 24h settings', (tester) async {
      final submitted = await pumpForm(tester);

      await tester.tap(find.text('Create link'));
      await tester.pump();

      expect(submitted, hasLength(1));
      expect(submitted.single.maxUses, 1);
      expect(submitted.single.expiresInSeconds, 86400);
      expect(submitted.single.alias, '');
      expect(submitted.single.allowUsingAsExitNode, isFalse);
      expect(submitted.single.label, '');
    });

    testWidgets('collects the name, the label and the exit node permission', (tester) async {
      final submitted = await pumpForm(tester);

      await tester.enterText(find.widgetWithText(TextField, nameField), ' laptop ');
      // The label is bookkeeping for this side only, so it stays folded away.
      await tester.tap(find.text('Add a link label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Link label'), 'my laptop');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.text('Create link'));
      await tester.pump();

      expect(submitted.single.alias, 'laptop');
      expect(submitted.single.label, 'my laptop');
      expect(submitted.single.allowUsingAsExitNode, isTrue);
    });

    testWidgets('a multi-use link sends the entered count and no name', (tester) async {
      final submitted = await pumpForm(tester);

      // Type a name first: switching to multi-use must drop it, because the
      // backend rejects an alias on a link several devices will redeem.
      await tester.enterText(find.widgetWithText(TextField, nameField), 'laptop');
      await tester.enterText(find.byKey(usesCount), '7');
      await tester.pumpAndSettle();

      // The field stays put and explains itself instead of vanishing.
      expect(find.widgetWithText(TextField, nameField), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, nameField)).enabled, isFalse);

      await tester.tap(find.text('Create link'));
      await tester.pump();

      expect(submitted.single.maxUses, 7);
      expect(submitted.single.alias, '');
    });

    testWidgets('typing a count selects the multi-use option by itself', (tester) async {
      final submitted = await pumpForm(tester);

      // Never touching the radio: entering a number is unambiguous intent.
      await tester.enterText(find.byKey(usesCount), '3');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create link'));
      await tester.pump();

      expect(submitted.single.maxUses, 3);
    });

    testWidgets('switching back to single use keeps the typed count', (tester) async {
      final submitted = await pumpForm(tester);

      await tester.enterText(find.byKey(usesCount), '9');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Single use'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Up to'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create link'));
      await tester.pump();

      expect(submitted.single.maxUses, 9);
    });

    testWidgets('a count outside the backend range is refused before sending', (tester) async {
      final submitted = await pumpForm(tester);

      await tester.enterText(find.byKey(usesCount), '900');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create link'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a number from 2 to 100'), findsOneWidget);
      expect(submitted, isEmpty);
    });

    testWidgets('never-expiring option sends 0 seconds', (tester) async {
      final submitted = await pumpForm(tester);

      await tester.tap(find.text('24 hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Never').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create link'));
      await tester.pump();

      expect(submitted.single.expiresInSeconds, 0);
    });

    testWidgets('resolves the picked duration to a moment, in one place only', (tester) async {
      await pumpForm(tester);

      // 24 hours from the injected clock. The summary is the only place it is
      // stated — the dropdown deliberately does not repeat the timestamp.
      expect(find.textContaining('tomorrow at 09:00'), findsOneWidget);

      await tester.tap(find.text('24 hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20 minutes').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('today at 09:20'), findsOneWidget);
    });

    testWidgets('the summary states the terms of the link as chosen', (tester) async {
      await pumpForm(tester);

      expect(
        find.text('Anyone who has this link can join until tomorrow at 09:00 (one device).'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(usesCount), '4');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Anyone who has this link can join until tomorrow at 09:00 (up to 4 devices). '
          "They'll be able to route internet traffic through this device.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('a rejected request keeps the form and what was typed', (tester) async {
      var done = 0;
      await pumpForm(tester, fails: 'alias is too long', onDone: () => done++);

      await tester.enterText(find.widgetWithText(TextField, nameField), 'laptop');
      await tester.tap(find.text('Create link'));
      await tester.pumpAndSettle();

      expect(find.text('Could not create the link: alias is too long'), findsOneWidget);
      expect(find.text('laptop'), findsOneWidget);
      expect(done, 0);
    });

    testWidgets('a second attempt drops the message the first one earned', (tester) async {
      // The error answers one request. Left standing over a form the user has
      // changed in response to it, it reads as a verdict on the new settings.
      var pending = Completer<String>();
      await pumpAppWidget(
        tester,
        CreateInviteDialog(onSubmit: (_) => pending.future, now: DateTime(2026, 4, 10, 9)),
        size: desktopSize,
      );

      await tester.enterText(find.widgetWithText(TextField, nameField), 'a very long name');
      await tester.tap(find.text('Create link'));
      pending.complete('alias is too long');
      await tester.pumpAndSettle();
      expect(find.text('Could not create the link: alias is too long'), findsOneWidget);

      pending = Completer<String>();
      await tester.enterText(find.widgetWithText(TextField, nameField), 'laptop');
      await tester.tap(find.text('Create link'));
      // Mid-flight: the message is already gone, before any answer arrives.
      await tester.pump();
      expect(find.textContaining('Could not create the link'), findsNothing);

      pending.complete('');
      await tester.pumpAndSettle();
    });

    testWidgets('a second tap while the first create is in flight sends nothing', (tester) async {
      // Two links would be made, and only the second is shown afterwards — the
      // other stays in the list, where nothing can delete it.
      final submitted = <CreateInviteRequest>[];
      final pending = Completer<String>();
      await pumpAppWidget(
        tester,
        CreateInviteDialog(
          onSubmit: (request) {
            submitted.add(request);
            return pending.future;
          },
          now: DateTime(2026, 4, 10, 9),
        ),
        size: desktopSize,
      );

      await tester.tap(find.text('Create link'));
      await tester.pump();
      await tester.tap(find.text('Create link'));
      await tester.pump();

      expect(submitted, hasLength(1));

      pending.complete('');
      await tester.pumpAndSettle();
    });
  });

  // The dialog helpers are what the screen actually shows; pumping their
  // contents alone would miss the dialog shell they are laid out in — the QR
  // code in particular sits inside the route's IntrinsicWidth, which is fussy
  // about children that measure themselves with a LayoutBuilder.
  group('dialog helpers', () {
    Future<void> pumpOpener(WidgetTester tester, void Function(BuildContext) open) {
      return pumpDialogOpener(tester, open, size: desktopSize);
    }

    testWidgets('showInviteLinkDialog lays out the link and its QR code', (tester) async {
      final invite = invitesFixture().first;
      await pumpOpener(tester, (context) => showInviteLinkDialog(context, invite));

      expect(find.text(invite.link), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showCreateInviteDialog submits and closes on success', (tester) async {
      CreateInviteRequest? sent;
      var closed = 0;
      await pumpOpener(tester, (context) async {
        await showCreateInviteDialog(
          context,
          onSubmit: (request) async {
            sent = request;
            return '';
          },
        );
        closed++;
      });

      await tester.tap(find.text('Add a link label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Link label'), 'my laptop');
      await tester.tap(find.text('Create link'));
      await tester.pumpAndSettle();

      expect(sent?.label, 'my laptop');
      expect(sent?.maxUses, 1);
      expect(closed, 1);
    });

    testWidgets('showCreateInviteDialog submits nothing when cancelled', (tester) async {
      var calls = 0;
      var submits = 0;
      await pumpOpener(tester, (context) async {
        await showCreateInviteDialog(
          context,
          onSubmit: (request) async {
            submits++;
            return '';
          },
        );
        calls++;
      });

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(submits, 0);
    });

    testWidgets('revoke confirmation spells out that added devices stay', (tester) async {
      bool? confirmed;
      await pumpOpener(tester, (context) async {
        confirmed = await showRevokeInviteDialog(context, invitesFixture().first);
      });

      expect(find.textContaining('"my laptop" will stop working for new connections'), findsOneWidget);
      expect(find.textContaining('Devices already added through it stay'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Revoke link'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    testWidgets('revoke confirmation says no when cancelled', (tester) async {
      bool? confirmed;
      await pumpOpener(tester, (context) async {
        confirmed = await showRevokeInviteDialog(context, invitesFixture().first);
      });

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
    });
  });

  group('InviteLinkPanel', () {
    testWidgets('shows the link, its usage and the expiry date', (tester) async {
      final invite = invitesFixture().first;
      await pumpAppWidget(tester, InviteLinkPanel(invite: invite), size: desktopSize);

      expect(find.text(invite.link), findsOneWidget);
      expect(find.text('0/1 used · expires ${formatInviteDateTime(invite.expiresAt)}'), findsOneWidget);
    });

    testWidgets('says so for a link with no expiry', (tester) async {
      await pumpAppWidget(tester, InviteLinkPanel(invite: invitesFixture().last), size: desktopSize);

      // The detail view keeps the raw counts the list drops: here they are what
      // the reader came for.
      expect(find.text('1/5 used · never expires'), findsOneWidget);
    });
  });
}
