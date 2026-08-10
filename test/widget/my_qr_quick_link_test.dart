/// The one piece of [MyQRDialog] that talks to the backend: finding a
/// still-good quick link or making one.
///
/// Tested through the adapter rather than the view, because reuse-or-create is
/// exactly what the adapter is — the view is covered in `qr_dialog_test.dart`
/// with the call stubbed out.
library;

import 'dart:convert';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/invites_screen.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/qr_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/load_fonts.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

const _peerID = samplePeerID;
const _baseUrl = 'http://test.local';

/// One invite as the backend sends it. Only the fields this flow looks at
/// carry meaning; the rest are filler.
Map<String, dynamic> _inviteJson({
  String id = 'inv-1',
  String label = quickQRInviteLabel,
  String status = inviteStatusActive,
  int maxUses = 1,
  int usedCount = 0,
  String alias = '',
  bool allowUsingAsExitNode = false,
  String token = 'ReusedToken1234567890',
}) {
  return {
    'ID': id,
    'Label': label,
    'Link': 'awl://invite?p=$_peerID&t=$token&n=my-laptop',
    'Alias': alias,
    'AllowUsingAsExitNode': allowUsingAsExitNode,
    'MaxUses': maxUses,
    'UsedCount': usedCount,
    'ExpiresAt': '2026-04-10T21:00:00Z',
    'CreatedAt': '2026-04-10T09:00:00Z',
    'Revoked': false,
    'Status': status,
  };
}

void main() {
  setUpAll(() {
    registerHttpFallbacks();
    loadTestFonts();
  });

  late MockHttpClient client;

  setUp(() {
    client = MockHttpClient();
    serverAddress = _baseUrl;
  });

  /// Answers `invites/list` with [existing] and `invites/create` with a link
  /// whose token says it was freshly made. Posts go out through `send`, which
  /// is what [ApiClient] uses for every request with a body.
  void stubBackend(List<Map<String, dynamic>> existing) {
    when(() => client.get(any())).thenAnswer((_) async => http.Response(jsonEncode(existing), 200));
    when(() => client.send(any())).thenAnswer(
      (_) async => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(_inviteJson(id: 'created', token: 'CreatedToken98765')))),
        200,
      ),
    );
  }

  Future<void> pumpDialog(WidgetTester tester) {
    // The default 800x600 test view is shorter than this dialog, which would
    // leave its last row scrolled out of reach of a tap.
    return pumpDialogOpener(
      tester,
      (context) => showMyQRDialog(context, _peerID, 'my-laptop'),
      size: dialogSize,
      overrides: [httpClientProvider.overrideWithValue(client)],
      routes: {InvitesScreen.routeName: (_) => const Scaffold(body: Text('the invites screen'))},
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await pumpDialog(tester);
    await tester.tap(find.text('One-time link'));
    await tester.pumpAndSettle();
  }

  /// The body of the one create request, decoded.
  Map<String, dynamic> createdRequest() {
    final captured = verify(() => client.send(captureAny())).captured;
    expect(captured, hasLength(1));
    final request = captured.single as http.Request;
    expect(request.url.toString(), '$_baseUrl$createInvitePath');
    return jsonDecode(request.body) as Map<String, dynamic>;
  }

  testWidgets('creates a single-use link with no rights and a 12h life', (tester) async {
    stubBackend([]);
    await openDialog(tester);

    final request = createdRequest();
    expect(request['MaxUses'], 1);
    expect(request['ExpiresInSeconds'], quickQRInviteTTL.inSeconds);
    expect(request['AllowUsingAsExitNode'], isFalse);
    expect(request['Label'], quickQRInviteLabel);
    // No alias: the device that joins keeps the name it gives itself.
    expect(request['Alias'], '');
    // And it is the created link that ends up on screen, not the one we asked
    // the list for.
    expect(tester.widget<LinkSharePanel>(find.byType(LinkSharePanel)).link, contains('CreatedToken98765'));
  });

  testWidgets('reuses a quick link that is still good', (tester) async {
    stubBackend([_inviteJson()]);
    await openDialog(tester);

    verifyNever(() => client.send(any()));
  });

  testWidgets('makes a new one when the old one is spent, expired or revoked', (tester) async {
    // The label alone would match all three of these; the state is what
    // decides. `usedCount` matters on its own: a single-use link that has been
    // redeemed can still be reported active by a backend that has not caught
    // up with it.
    stubBackend([
      _inviteJson(id: 'used-up', status: inviteStatusUsedUp, usedCount: 1),
      _inviteJson(id: 'expired', status: inviteStatusExpired),
      _inviteJson(id: 'revoked', status: inviteStatusRevoked),
      _inviteJson(id: 'redeemed', usedCount: 1),
    ]);
    await openDialog(tester);

    createdRequest();
  });

  testWidgets('leaves other people\'s links alone', (tester) async {
    // An ordinary link the user made on the invites screen is not ours to hand
    // out from here, however well its settings happen to match.
    stubBackend([_inviteJson(id: 'handmade', label: 'for the office')]);
    await openDialog(tester);

    createdRequest();
  });

  testWidgets('never reuses a multi-use link', (tester) async {
    stubBackend([_inviteJson(id: 'multi', maxUses: 5)]);
    await openDialog(tester);

    createdRequest();
  });

  testWidgets('never reuses a link that grants more than the quick path does', (tester) async {
    // The label is ordinary text and can be typed into the create form by
    // hand, so a link wearing it may carry settings this path never grants.
    // Matching on the label alone would hand out routing rights from a button
    // that promises none.
    stubBackend([
      _inviteJson(id: 'exit-node', allowUsingAsExitNode: true),
      _inviteJson(id: 'aliased', alias: 'office-laptop'),
    ]);
    await openDialog(tester);

    createdRequest();
  });

  testWidgets('Manage links closes the dialog and opens the invites screen', (tester) async {
    // The navigation happens off the dialog's own context, which is defunct
    // the moment it is popped — the order of those two steps is the test.
    stubBackend([]);
    await pumpDialog(tester);

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Manage links')));
    await tester.pumpAndSettle();

    expect(find.text('the invites screen'), findsOneWidget);
    expect(find.text('Your link'), findsNothing);
  });

  testWidgets('a refusing backend leaves the dialog on the safe link', (tester) async {
    when(() => client.get(any())).thenAnswer((_) async => http.Response('nope', 500));
    await openDialog(tester);

    expect(find.textContaining('still has to be accepted'), findsOneWidget);
    expect(find.textContaining('Failed to fetchInvites'), findsOneWidget);
  });
}
