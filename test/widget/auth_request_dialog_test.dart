import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/load_fonts.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

const _peerID = otherPeerID;

void main() {
  setUpAll(loadTestFonts);

  const desktopSize = dialogSize;

  AuthRequest request({String name = 'vasya-laptop', String ip = '10.66.0.7'}) =>
      AuthRequest(_peerID, name, ip);

  /// Pumps the view and returns every reply it sent, in order. [error] is what
  /// the injected submit reports back — "" is success.
  Future<List<FriendRequestReply>> pumpDialog(
    WidgetTester tester, {
    AuthRequest? incoming,
    String error = '',
    VoidCallback? onDone,
    Size size = desktopSize,
  }) async {
    final sent = <FriendRequestReply>[];
    await pumpAppWidget(
      tester,
      AuthRequestDialogView(
        request: incoming ?? request(),
        onDone: onDone,
        onSubmit: (reply) async {
          sent.add(reply);
          return error;
        },
      ),
      size: size,
    );
    await tester.pumpAndSettle();
    return sent;
  }

  Future<void> tapAccept(WidgetTester tester) async {
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens filled in with what the requester sent', (tester) async {
    await pumpDialog(tester);

    expect(find.text(_peerID), findsOneWidget);
    expect(find.text('vasya-laptop'), findsWidgets);
    expect(find.text('10.66.0.7'), findsOneWidget);
    // The name is theirs but ours to change, so it is offered as a suggestion.
    expect(find.textContaining("Incoming friend request from 'vasya-laptop'"), findsOneWidget);
  });

  testWidgets('an unnamed requester gets a title that does not quote an empty name', (tester) async {
    await pumpDialog(tester, incoming: request(name: ''));

    expect(find.text('Incoming friend request'), findsOneWidget);
  });

  testWidgets('the peer id is read-only: it identifies them, it is not a field', (tester) async {
    await pumpDialog(tester);

    // Read off the TextField the form field builds: `readOnly` is a builder
    // argument on TextFormField, not a property of it.
    final field = tester.widget<TextField>(
      find.descendant(of: find.widgetWithText(TextFormField, _peerID), matching: find.byType(TextField)),
    );
    expect(field.readOnly, isTrue);
  });

  testWidgets('Accept replies with the name and IP as edited', (tester) async {
    final sent = await pumpDialog(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'vasya-laptop'), 'vasya');
    await tester.enterText(find.widgetWithText(TextFormField, '10.66.0.7'), '10.66.0.9');
    await tapAccept(tester);

    expect(sent, hasLength(1));
    expect(sent.single.peerID, _peerID);
    expect(sent.single.alias, 'vasya');
    expect(sent.single.ipAddr, '10.66.0.9');
    expect(sent.single.decline, isFalse);
  });

  testWidgets('Decline sends the same reply, marked declined', (tester) async {
    final sent = await pumpDialog(tester);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(sent.single.decline, isTrue);
    expect(sent.single.peerID, _peerID);
  });

  testWidgets('the exit-node permission is off unless granted, and rides along with Accept', (tester) async {
    final sent = await pumpDialog(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tapAccept(tester);

    expect(sent.single.allowUsingAsExitNode, isTrue);
  });

  testWidgets('granting nothing sends nothing granted', (tester) async {
    final sent = await pumpDialog(tester);

    await tapAccept(tester);

    expect(sent.single.allowUsingAsExitNode, isFalse);
  });

  testWidgets('the permission is explained where it is granted', (tester) async {
    await pumpDialog(tester);

    // The same wording as the add-peer form and peer settings: "this device" is
    // always the one in the user's hands.
    expect(find.byType(ExitNodePermissionField), findsOneWidget);
    expect(find.text('Allow them to use this device as an exit node'), findsOneWidget);
  });

  testWidgets('a malformed IP is refused before anything is sent', (tester) async {
    final sent = await pumpDialog(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '10.66.0.7'), 'not-an-ip');
    await tapAccept(tester);

    expect(sent, isEmpty);
    expect(find.text('Invalid IPv4 address format'), findsOneWidget);
  });

  testWidgets('a rejected reply keeps the dialog open and says why', (tester) async {
    var done = false;
    await pumpDialog(tester, error: 'peer has already been added', onDone: () => done = true);

    await tapAccept(tester);

    expect(done, isFalse);
    expect(find.textContaining('peer has already been added'), findsOneWidget);
  });

  testWidgets('a successful reply closes the dialog through onDone', (tester) async {
    var done = false;
    await pumpDialog(tester, onDone: () => done = true);

    await tapAccept(tester);

    expect(done, isTrue);
  });

  testWidgets('Decline and Accept stay reachable on a short screen', (tester) async {
    // What `scrollable: true` buys: three fields, a checkbox with a two-line
    // subtitle and a paragraph do not fit a landscape phone, and before the
    // dialog unification the action row was pushed off instead of the fields
    // scrolling under it.
    await pumpDialog(tester, size: phoneLandscapeSize);

    expect(tester.takeException(), isNull);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });
}
