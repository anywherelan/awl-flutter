/// The blocked peers screen on both sides of its seam: [BlockedPeersView] with
/// its data handed in, and [BlockedPeersScreen] over a mocked http client for
/// the one thing the adapter does, which is unblocking.
library;

import 'dart:convert';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/blocked_peers_screen.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

const _baseUrl = 'http://test.local';

const _printerID = otherPeerID;
const _laptopID = '12D3KooWMASi45ub7Qe4ZE36UT5G6cU4ud8Fhhe4deS4F3cw9KTA';

/// Local wall clock, as in `blocked_peers_text_test.dart`, where the wording of
/// the dates is checked; here they only have to reach the screen.
final _now = DateTime(2026, 4, 10, 9);

final _printer = BlockedPeer(_printerID, 'office-printer', DateTime(2026, 4, 10, 8, 41));
final _laptop = BlockedPeer(_laptopID, 'old laptop', DateTime(2023, 9, 17, 20, 17));

/// Every row carries the same button, so it is looked up through the card of
/// the peer it belongs to.
Finder _unblockButtonOf(String name) {
  return find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(Card)),
    matching: find.widgetWithText(TextButton, 'Unblock peer'),
  );
}

/// The action keeps its name from the row into the dialog's title and its
/// confirmation, so anything about the dialog is looked up inside it.
Finder _inDialog(Finder matching) => find.descendant(of: find.byType(AlertDialog), matching: matching);

void main() {
  group('BlockedPeersView', () {
    testWidgets('shows a spinner while the list is loading', (tester) async {
      await pumpAppWidget(tester, const BlockedPeersView(peers: null));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the error instead of the list', (tester) async {
      await pumpAppWidget(
        tester,
        const BlockedPeersView(peers: <BlockedPeer>[], error: 'server unavailable'),
      );

      expect(find.text('server unavailable'), findsOneWidget);
      expect(find.text('No blocked peers'), findsNothing);
    });

    testWidgets('empty state says how a peer would get here', (tester) async {
      await pumpAppWidget(tester, const BlockedPeersView(peers: <BlockedPeer>[]));

      expect(find.text('No blocked peers'), findsOneWidget);
      expect(find.textContaining('remove them from your peers'), findsOneWidget);
      expect(find.text('Unblock peer'), findsNothing);
    });

    testWidgets('renders each peer with its name, date and whole id', (tester) async {
      await pumpAppWidget(tester, BlockedPeersView(peers: [_printer, _laptop], now: _now));

      expect(find.text('office-printer'), findsOneWidget);
      expect(find.text('old laptop'), findsOneWidget);
      expect(find.text(blockedSinceText(_printer.createdAt, now: _now)), findsOneWidget);
      expect(find.text(blockedSinceText(_laptop.createdAt, now: _now)), findsOneWidget);
      // In full: it is the only thing that tells two peers of one name apart.
      expect(find.text(_printerID), findsOneWidget);
      expect(find.text(_laptopID), findsOneWidget);

      // Removed peers are here too, though nobody "blocked" them, and adding
      // one again is the other way out of the list.
      expect(find.textContaining('Peers you declined or removed'), findsOneWidget);
      expect(find.textContaining('until you unblock them or add them again'), findsOneWidget);
    });

    testWidgets('a peer that never named itself is still a row', (tester) async {
      await pumpAppWidget(
        tester,
        BlockedPeersView(peers: [BlockedPeer(_printerID, '', _printer.createdAt)], now: _now),
      );

      expect(find.text('Unnamed peer'), findsOneWidget);
      expect(_unblockButtonOf('Unnamed peer'), findsOneWidget);
    });

    testWidgets('a name cannot open a second line under itself', (tester) async {
      // The name is the peer's own text. Given a newline it could otherwise
      // write its own "blocked …" line, in the title's style.
      const name = 'printer\nblocked today at 08:59';
      await pumpAppWidget(
        tester,
        BlockedPeersView(peers: [BlockedPeer(_printerID, name, _printer.createdAt)], now: _now),
      );

      expect(tester.widget<Text>(find.text(name)).maxLines, 1);
    });

    testWidgets('the button hands over the peer of its own row', (tester) async {
      final unblocked = <BlockedPeer>[];
      await pumpAppWidget(
        tester,
        BlockedPeersView(
          peers: [_printer, _laptop],
          now: _now,
          onUnblock: (peer) async => unblocked.add(peer),
        ),
      );

      await tester.tap(_unblockButtonOf('old laptop'));

      expect(unblocked.single.peerId, _laptopID);
    });
  });

  group('unblock confirmation', () {
    Future<void> openDialog(WidgetTester tester, BlockedPeer peer) {
      return pumpDialogOpener(tester, (context) => showUnblockPeerDialog(context, peer));
    }

    testWidgets('names the peer and says what unblocking does not do', (tester) async {
      await openDialog(tester, _printer);

      expect(_inDialog(find.textContaining('"office-printer" will be able to send you')), findsOneWidget);
      expect(_inDialog(find.textContaining('does not add them to your peers')), findsOneWidget);
    });

    testWidgets('does not quote a name the peer does not have', (tester) async {
      await openDialog(tester, BlockedPeer(_printerID, '', _printer.createdAt));

      expect(_inDialog(find.textContaining('This peer will be able to send you')), findsOneWidget);
    });

    testWidgets('answers with the button that was pressed', (tester) async {
      bool? answer;
      Future<void> open(BuildContext context) async =>
          answer = await showUnblockPeerDialog(context, _printer);

      await pumpDialogOpener(tester, open);
      await tester.tap(_inDialog(find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(answer, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(_inDialog(find.widgetWithText(TextButton, 'Unblock peer')));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });
  });

  group('BlockedPeersScreen', () {
    late MockHttpClient client;

    /// What `peers/get_blocked` answers with. Mutable, so that the mocked
    /// backend can drop a peer and the refetch has something to show for it.
    late List<Map<String, dynamic>> blocked;

    setUpAll(registerHttpFallbacks);

    setUp(() {
      client = MockHttpClient();
      serverAddress = _baseUrl;
      blocked = [_printer.toJson(), _laptop.toJson()];
      when(() => client.get(any())).thenAnswer((_) async => http.Response(jsonEncode(blocked), 200));
    });

    /// Answers `peers/unblock`. With [removes] it also does what the backend
    /// does on success, taking the peer off the list.
    void stubUnblock(String body, int status, {bool removes = false}) {
      when(() => client.send(any())).thenAnswer((invocation) async {
        if (removes) {
          final request = invocation.positionalArguments.single as http.Request;
          final peerID = (jsonDecode(request.body) as Map<String, dynamic>)['PeerID'];
          blocked.removeWhere((peer) => peer['peerId'] == peerID);
        }
        return http.StreamedResponse(Stream.value(utf8.encode(body)), status);
      });
    }

    Future<void> pumpScreen(WidgetTester tester) async {
      await pumpAppWidget(
        tester,
        const BlockedPeersScreen(),
        overrides: [httpClientProvider.overrideWithValue(client)],
      );
      await tester.pumpAndSettle();
    }

    Future<void> unblock(WidgetTester tester, String name) async {
      await tester.tap(_unblockButtonOf(name));
      await tester.pumpAndSettle();
      await tester.tap(_inDialog(find.widgetWithText(TextButton, 'Unblock peer')));
      await tester.pumpAndSettle();
    }

    testWidgets('unblocking posts the peer id, rereads the list and says so', (tester) async {
      stubUnblock('', 200, removes: true);
      await pumpScreen(tester);

      await unblock(tester, 'office-printer');

      final request = verify(() => client.send(captureAny())).captured.single as http.Request;
      expect(request.url.toString(), '$_baseUrl$unblockPeerPath');
      expect(jsonDecode(request.body), {'PeerID': _printerID});

      expect(find.text('office-printer'), findsNothing);
      expect(find.text('old laptop'), findsOneWidget);
      expect(find.text('"office-printer" unblocked'), findsOneWidget);
    });

    testWidgets('backing out of the confirmation sends nothing', (tester) async {
      stubUnblock('', 200, removes: true);
      await pumpScreen(tester);

      await tester.tap(_unblockButtonOf('office-printer'));
      await tester.pumpAndSettle();
      await tester.tap(_inDialog(find.text('Cancel')));
      await tester.pumpAndSettle();

      verifyNever(() => client.send(any()));
      expect(find.text('office-printer'), findsOneWidget);
    });

    testWidgets('a refusal is shown, and the list is reread anyway', (tester) async {
      // The likeliest refusal: the peer was unblocked from somewhere else, so
      // the list this screen is showing is the thing that is wrong.
      stubUnblock('{"error": "peer is not blocked"}', 404);
      await pumpScreen(tester);
      blocked.removeWhere((peer) => peer['peerId'] == _printerID);

      await unblock(tester, 'office-printer');

      expect(find.text('Failed to unblock peer: peer is not blocked'), findsOneWidget);
      expect(find.text('office-printer'), findsNothing);
    });

    testWidgets('an answer that is not in the API\'s error shape is reported, not thrown', (tester) async {
      // What a backend older than this endpoint sends back.
      stubUnblock('{"message":"Method Not Allowed"}', 405);
      await pumpScreen(tester);

      await unblock(tester, 'office-printer');

      expect(find.textContaining('Failed to unblock peer: '), findsOneWidget);
      expect(find.text('office-printer'), findsOneWidget);
    });
  });
}
