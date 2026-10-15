import 'dart:async';

import 'package:anywherelan/add_peer.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

const _peerID = samplePeerID;
const _token = sampleToken;
const _link = sampleInviteLink;

/// A link that only identifies its author: the shareable form of a peer ID,
/// which `showPeerQRDialog` hands out. Added by hand like any peer.
const _tokenlessLink = sampleTokenlessLink;

/// Broken beyond use — the peer id is not one.
const _brokenLink = sampleBrokenLink;

void main() {
  const desktopSize = dialogSize;

  Finder inputField() => find.widgetWithText(TextFormField, 'Invite link or Peer ID');
  Finder nameField() => find.widgetWithText(TextFormField, 'Name');
  // The dialog title says "Add peer" too, so the submit button is matched by
  // its type rather than by its label alone.
  Finder addButton() => find.widgetWithText(FilledButton, 'Add peer');
  // Scanning fills the link field, so it is that field's trailing button.
  Finder scanButton() => find.byTooltip('Scan QR code');

  group('AddPeerDialogView', () {
    testWidgets('starts collapsed: only the link/id field is shown', (tester) async {
      await pumpAppWidget(tester, AddPeerDialogView(onSubmit: (_) async => ''), size: desktopSize);

      expect(inputField(), findsOneWidget);
      expect(nameField(), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Local IP address'), findsNothing);
    });

    testWidgets('opens unfolded and parsed when a deep link prefills it', (tester) async {
      FriendRequest? sent;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(
          initialInput: _link,
          onSubmit: (request) async {
            sent = request;
            return '';
          },
        ),
        size: desktopSize,
      );

      // Same state as if the link had been pasted: no extra tap needed.
      expect(find.text(_link), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.textContaining("You'll connect using an invite link"), findsOneWidget);

      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(sent!.peerID, _peerID);
      expect(sent!.token, _token);
    });

    testWidgets('a prefilled broken link is reported, not silently accepted', (tester) async {
      await pumpAppWidget(
        tester,
        AddPeerDialogView(initialInput: _brokenLink, onSubmit: (_) async => ''),
        size: desktopSize,
      );

      expect(find.text('Invite link has an invalid peer id'), findsOneWidget);
      expect(nameField(), findsNothing);
    });

    testWidgets('unfolds for a plain peer id, without invite wording', (tester) async {
      await pumpAppWidget(tester, AddPeerDialogView(onSubmit: (_) async => ''), size: desktopSize);

      await tester.enterText(inputField(), _peerID);
      await tester.pump();

      expect(nameField(), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Local IP address'), findsOneWidget);
      expect(find.textContaining("You'll connect using an invite link"), findsNothing);
    });

    testWidgets('an invite link prefills the name and explains what happens', (tester) async {
      await pumpAppWidget(tester, AddPeerDialogView(onSubmit: (_) async => ''), size: desktopSize);

      await tester.enterText(inputField(), _link);
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Taken from the link, you can change it'), findsOneWidget);
      expect(find.textContaining("You'll connect using an invite link"), findsOneWidget);
    });

    testWidgets('a link without a token promises no automatic accept', (tester) async {
      FriendRequest? sent;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(
          onSubmit: (request) async {
            sent = request;
            return '';
          },
        ),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _tokenlessLink);
      await tester.pump();

      // Unfolds and prefills exactly like an invitation…
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Taken from the link, you can change it'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Local IP address'), findsOneWidget);
      // …but nothing on the other side accepts us on its own, so the form says
      // nothing about it — this is a plain peer id in link clothing.
      expect(find.textContaining("You'll connect using an invite link"), findsNothing);

      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(sent!.peerID, _peerID);
      expect(sent!.token, '');
      expect(sent!.alias, 'Alice');
    });

    testWidgets('a name typed by the user survives editing the link', (tester) async {
      FriendRequest? sent;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(
          onSubmit: (request) async {
            sent = request;
            return '';
          },
        ),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _link);
      await tester.pump();
      await tester.enterText(nameField(), 'My phone');
      await tester.pump();
      // Re-pasting the same link must not undo the rename.
      await tester.enterText(inputField(), _link);
      await tester.pump();

      await tester.tap(addButton());
      await tester.pumpAndSettle();
      expect(sent!.alias, 'My phone');
    });

    testWidgets('the name from a link is dropped when the link is replaced', (tester) async {
      FriendRequest? sent;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(
          onSubmit: (request) async {
            sent = request;
            return '';
          },
        ),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _link);
      await tester.pump();
      expect(find.text('Alice'), findsOneWidget);

      // A bare peer id is a different peer: Alice's name must not ride along.
      await tester.enterText(inputField(), _peerID);
      await tester.pump();
      expect(find.text('Alice'), findsNothing);

      await tester.enterText(nameField(), 'Bob');
      await tester.tap(addButton());
      await tester.pumpAndSettle();
      expect(sent!.alias, 'Bob');
    });

    testWidgets('sends peer id and token from the link', (tester) async {
      FriendRequest? sent;
      var done = 0;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(
          onSubmit: (request) async {
            sent = request;
            return '';
          },
          onDone: () => done++,
        ),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _link);
      await tester.pump();
      // Tapping the label, not the box: the whole row is the target.
      await tester.tap(find.text('Allow them to use this device as an exit node'));
      await tester.pump();
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      expect(sent!.peerID, _peerID);
      expect(sent!.token, _token);
      expect(sent!.alias, 'Alice');
      expect(sent!.allowUsingAsExitNode, isTrue);
      expect(done, 1);
    });

    testWidgets('sends the raw input as peer id when it is not a link', (tester) async {
      FriendRequest? sent;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(
          onSubmit: (request) async {
            sent = request;
            return '';
          },
        ),
        size: desktopSize,
      );

      await tester.enterText(inputField(), '  $_peerID  ');
      await tester.pump();
      await tester.enterText(nameField(), 'Bob');
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(sent!.peerID, _peerID);
      expect(sent!.token, '');
      expect(sent!.alias, 'Bob');
    });

    testWidgets('a broken invite link is reported and blocks submit', (tester) async {
      var submits = 0;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(
          onSubmit: (_) async {
            submits++;
            return '';
          },
        ),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _brokenLink);
      await tester.pump();

      expect(find.text('Invite link has an invalid peer id'), findsOneWidget);
      // The rest of the form stays folded — there is nothing to fill in yet.
      expect(nameField(), findsNothing);

      await tester.tap(addButton());
      await tester.pumpAndSettle();
      expect(submits, 0);
    });

    testWidgets('a link from a newer awl explains itself', (tester) async {
      await pumpAppWidget(tester, AddPeerDialogView(onSubmit: (_) async => ''), size: desktopSize);

      await tester.enterText(inputField(), 'awl://invite?p=$_peerID&t=$_token&v=99');
      await tester.pump();

      expect(find.textContaining('newer version of anywherelan'), findsOneWidget);
    });

    testWidgets('a server error is shown and the form stays open', (tester) async {
      var done = 0;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(onSubmit: (_) async => 'peer has already been added', onDone: () => done++),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _link);
      await tester.pump();
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.text('Could not add the peer: peer has already been added'), findsOneWidget);
      expect(done, 0);
    });

    // The backend answers with a text and no field, so the message is the
    // form's, not the first field's: under "Invite link or Peer ID" a rejected
    // name or an unreachable server read as a wrong peer id.
    testWidgets('a server error is not attached to the input field', (tester) async {
      await pumpAppWidget(
        tester,
        AddPeerDialogView(onSubmit: (_) async => 'peer name is not unique'),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _link);
      await tester.pump();
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      final decorations = tester.widgetList<InputDecorator>(find.byType(InputDecorator));
      expect(decorations.map((d) => d.decoration.errorText), everyElement(isNull));
      expect(find.textContaining('peer name is not unique'), findsOneWidget);
    });

    testWidgets('the error of one attempt is gone once the next one starts', (tester) async {
      final answers = ['peer name is not unique', ''];
      var done = 0;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(onSubmit: (_) async => answers.removeAt(0), onDone: () => done++),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _link);
      await tester.pump();
      await tester.tap(addButton());
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not add the peer'), findsOneWidget);

      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not add the peer'), findsNothing);
      expect(done, 1);
    });

    // A request that hangs used to look exactly like the button doing nothing,
    // and a second tap sent the friend request twice.
    testWidgets('while the request is in flight the button is off and sends nothing more', (tester) async {
      final answer = Completer<String>();
      var submits = 0;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(
          onSubmit: (_) {
            submits++;
            return answer.future;
          },
        ),
        size: desktopSize,
      );

      await tester.enterText(inputField(), _link);
      await tester.pump();
      await tester.tap(addButton());
      await tester.pump();

      expect(tester.widget<FilledButton>(addButton()).onPressed, isNull);
      await tester.tap(addButton(), warnIfMissed: false);
      await tester.pump();
      expect(submits, 1);

      answer.complete('peer has already been added');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(addButton()).onPressed, isNotNull);
    });

    // Nothing closes the form here, so it has to come back to life by itself.
    testWidgets('the button is back on after a success that leaves the form open', (tester) async {
      await pumpAppWidget(tester, AddPeerDialogView(onSubmit: (_) async => ''), size: desktopSize);

      await tester.enterText(inputField(), _link);
      await tester.pump();
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(addButton()).onPressed, isNotNull);
    });

    testWidgets('a scanned link fills the form the same way as a pasted one', (tester) async {
      await pumpAppWidget(
        tester,
        AddPeerDialogView(onSubmit: (_) async => '', onScanQR: () async => _link),
        size: desktopSize,
      );

      await tester.tap(scanButton());
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.textContaining("You'll connect using an invite link"), findsOneWidget);
    });

    testWidgets('hides Scan QR when scanning is unavailable', (tester) async {
      await pumpAppWidget(tester, AddPeerDialogView(onSubmit: (_) async => ''), size: desktopSize);

      expect(scanButton(), findsNothing);
    });

    testWidgets('offers the invite-link shortcut only when it can navigate', (tester) async {
      var opened = 0;
      await pumpAppWidget(
        tester,
        AddPeerDialogView(onSubmit: (_) async => '', onCreateInviteLink: () => opened++),
        size: desktopSize,
      );

      await tester.tap(find.text('Or invite someone with a link'));
      expect(opened, 1);
    });

    testWidgets('Cancel closes without sending anything', (tester) async {
      // Opened as a real route: Cancel pops the dialog itself rather than going
      // through onDone, which needs a route to pop.
      var submits = 0;
      await pumpDialogOpener(
        tester,
        (context) => showDialog<void>(
          context: context,
          builder: (_) => AddPeerDialogView(
            initialInput: _link,
            onSubmit: (_) async {
              submits++;
              return '';
            },
          ),
        ),
        size: desktopSize,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(submits, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
