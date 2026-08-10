/// Screenshot ("golden") tests for the invite-link screens.
///
/// Pixel comparisons, so CI pins `FLUTTER_VERSION` exactly and uploads the
/// actual/expected/diff images as the `golden-failures` artifact on a
/// mismatch — look at those before deciding whether the UI broke or the
/// toolchain moved. Re-shoot from the pinned version with:
///
/// ```
/// flutter test --tags golden --update-goldens
/// ```
@Tags(['golden'])
library;

import 'package:anywherelan/add_peer.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/invites_screen.dart';
import 'package:anywherelan/qr_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/golden.dart';
import '../helpers/load_fonts.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

const _peerID = samplePeerID;
const _link = sampleInviteLink;

/// The moment these images are rendered against.
///
/// Local wall clock, not [sampleNow], and every date below is a literal rather
/// than an offset from it: the screen prints timestamps in local time, so an
/// absolute instant photographs differently in every timezone — which is how
/// images shot in UTC+4 failed CI's UTC — and a derived one can straddle a DST
/// boundary.
final _now = DateTime(2026, 4, 10, 9);

Future<void> _openCreateInviteDialog(BuildContext context) {
  return showCreateInviteDialog(context, onSubmit: (_) async => '', now: _now);
}

/// Something in every slot — alias, exit-node rights, an expiry a day out —
/// hence also what the "created link" and revoke dialogs are shot with. The
/// link string is the fixture's, so those images carry a real QR code.
final _laptopInvite = makeInvite(
  id: '9f3a',
  label: 'my laptop',
  link: 'awl://invite?p=$samplePeerID&t=$sampleToken&n=myawesomelaptop',
  alias: 'laptop',
  allowUsingAsExitNode: true,
  expiresAt: DateTime(2026, 4, 11, 8, 24),
  createdAt: DateTime(2026, 4, 10, 8, 24),
);

/// The six states the list renders differently, newest first as the backend
/// returns them: last hour (warning colour), too far out for a countdown,
/// expired, active, used up, revoked.
List<Invite> _listWithEdgeCases() => [
  makeInvite(
    id: '7c1a',
    label: 'phone',
    alias: 'phone',
    expiresAt: DateTime(2026, 4, 10, 9, 12),
    createdAt: DateTime(2026, 4, 10, 8, 57),
  ),
  makeInvite(
    id: 'e5d2',
    allowUsingAsExitNode: true,
    maxUses: 5,
    usedCount: 2,
    expiresAt: DateTime(2027, 5, 15, 9),
    createdAt: DateTime(2026, 4, 9, 3),
  ),
  makeInvite(
    id: 'b30f',
    label: 'for the office',
    expiresAt: DateTime(2026, 4, 9, 14),
    createdAt: DateTime(2026, 4, 8, 9),
    status: inviteStatusExpired,
  ),
  _laptopInvite,
  makeInvite(
    id: '1b7d',
    label: 'friends',
    maxUses: 2,
    usedCount: 2,
    expiresAt: DateTime(2026, 4, 17, 8, 20),
    createdAt: DateTime(2026, 4, 10, 8, 20),
    status: inviteStatusUsedUp,
  ),
  makeInvite(
    id: 'c04e',
    maxUses: 5,
    usedCount: 1,
    createdAt: DateTime(2026, 4, 9, 19, 2),
    revoked: true,
    status: inviteStatusRevoked,
  ),
];

/// What the "My QR" dialog hands out in one-time mode.
final _quickInvite = makeInvite(id: 'q1', label: quickQRInviteLabel, expiresAt: _now.add(quickQRInviteTTL));

/// The app bar and background the screen is actually seen with.
Widget _screen(String title, Widget body, {Widget? floatingActionButton}) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    floatingActionButton: floatingActionButton,
    body: body,
  );
}

void main() {
  setUpAll(loadTestFonts);

  const phone = phoneSize;
  // Not [dialogSize]: an image's dimensions are part of what CI compares.
  const wide = Size(900, 1000);

  group('creator side', () {
    testWidgets('invites list', (tester) async {
      await pumpAppWidget(
        tester,
        _screen(
          'Invite links',
          InvitesView(
            invites: _listWithEdgeCases(),
            now: _now,
            onCreate: () async {},
            onRevoke: (_) async {},
            onShowLink: (_) async {},
          ),
          // Narrow: "Create link" stays a FAB, where a thumb can reach it.
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(Icons.add_link),
            label: const Text('Create link'),
          ),
        ),
        size: phone,
      );

      await expectGolden(tester, 'invites_list');
    });

    // The other placement of the same button: a header row above the list,
    // since a FAB in a wide window's corner is nowhere near the column being
    // read.
    testWidgets('invites list, wide layout', (tester) async {
      await pumpAppWidget(
        tester,
        _screen(
          'Invite links',
          InvitesView(
            invites: _listWithEdgeCases(),
            now: _now,
            showCreateInHeader: true,
            onCreate: () async {},
            onRevoke: (_) async {},
            onShowLink: (_) async {},
          ),
        ),
        size: wide,
      );

      await expectGolden(tester, 'invites_list_wide');
    });

    testWidgets('invites list empty state', (tester) async {
      await pumpAppWidget(
        tester,
        _screen('Invite links', InvitesView(invites: const [], now: _now, onCreate: () async {})),
        size: phone,
      );

      await expectGolden(tester, 'invites_empty');
    });

    testWidgets('create invite form', (tester) async {
      await goldenOfDialog(tester, wide, 'invite_create_form', _openCreateInviteDialog);
    });

    // The other branch of the form: no name for a link several devices redeem,
    // and the label unfolded.
    testWidgets('create invite form, multi-use', (tester) async {
      await pumpAppWidget(
        tester,
        Builder(
          builder: (context) =>
              ElevatedButton(onPressed: () => _openCreateInviteDialog(context), child: const Text('open')),
        ),
        size: wide,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('inviteUsesCount')), '12');
      await tester.tap(find.text('Add a link label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Link label'), 'office rollout');
      await tester.tap(find.byType(Checkbox));

      await expectGolden(tester, 'invite_create_form_multi');
    });

    testWidgets('created link with QR', (tester) async {
      await goldenOfDialog(
        tester,
        wide,
        'invite_link_panel',
        (context) => showInviteLinkDialog(context, _laptopInvite),
      );
    });

    testWidgets('revoke confirmation', (tester) async {
      await goldenOfDialog(
        tester,
        wide,
        'invite_revoke_confirm',
        (context) => showRevokeInviteDialog(context, _laptopInvite),
      );
    });
  });

  // The form's three shapes — folded, unfolded, in error — not one per kind of
  // input: what it *says* about a plain peer id or a token-less link is
  // asserted in `test/widget/add_peer_test.dart`.
  group('receiver side', () {
    testWidgets('add peer form, nothing entered yet', (tester) async {
      await goldenOfDialog(tester, wide, 'add_peer_collapsed', (context) {
        showDialog<void>(
          context: context,
          builder: (_) => AddPeerDialogView(onSubmit: (_) async => '', onCreateInviteLink: () {}),
        );
      });
    });

    testWidgets('add peer form with an invite link pasted', (tester) async {
      await goldenOfDialog(tester, wide, 'add_peer_invite_link', (context) {
        showDialog<void>(
          context: context,
          builder: (_) => AddPeerDialogView(
            initialInput: _link,
            onSubmit: (_) async => '',
            onScanQR: () async => null,
            onCreateInviteLink: () {},
          ),
        );
      });
    });

    testWidgets('add peer form with a broken link', (tester) async {
      await goldenOfDialog(tester, wide, 'add_peer_broken_link', (context) {
        showDialog<void>(
          context: context,
          builder: (_) => AddPeerDialogView(
            initialInput: sampleBrokenLink,
            onSubmit: (_) async => '',
            onCreateInviteLink: () {},
          ),
        );
      });
    });
  });

  group('sharing your own link', () {
    testWidgets('a peer\'s QR dialog', (tester) async {
      await goldenOfDialog(
        tester,
        wide,
        'qr_dialog',
        (context) => showPeerQRDialog(context, _peerID, 'my-laptop'),
      );
    });

    testWidgets('my QR dialog, showing who I am', (tester) async {
      await goldenOfDialog(tester, wide, 'my_qr_dialog', (context) {
        showDialog<void>(
          context: context,
          builder: (_) => MyQRDialogView(
            peerID: _peerID,
            peerName: 'my-laptop',
            now: _now,
            onQuickLink: () async => QuickLinkResult(invite: _quickInvite),
            onManageLinks: () {},
          ),
        );
      });
    });

    testWidgets('my QR dialog, switched to a one-time link', (tester) async {
      // The dangerous half: same shape, a token in the link, its terms stated
      // above it.
      await goldenOfDialog(
        tester,
        wide,
        'my_qr_dialog_one_time',
        (context) {
          showDialog<void>(
            context: context,
            builder: (_) => MyQRDialogView(
              peerID: _peerID,
              peerName: 'my-laptop',
              now: _now,
              onQuickLink: () async => QuickLinkResult(invite: _quickInvite),
              onManageLinks: () {},
            ),
          );
        },
        afterOpen: (tester) async {
          await tester.tap(find.text('One-time link'));
          await tester.pumpAndSettle();
        },
      );
    });
  });
}
