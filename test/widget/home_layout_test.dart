/// The home screen over a mocked backend: what it stops offering once the
/// server stops answering.
library;

import 'package:anywherelan/connection_error.dart';
import 'package:anywherelan/main.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/home_backend.dart';
import '../helpers/load_fonts.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

void main() {
  late HomeBackend backend;

  setUpAll(() async {
    registerHttpFallbacks();
    // The status cards are laid out for Roboto and overflow under the box font.
    await loadTestFonts();
  });

  setUp(() => backend = HomeBackend());

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    await pumpAppWidget(
      tester,
      const HomeLayout(title: 'Anywherelan'),
      size: size,
      overrides: [httpClientProvider.overrideWithValue(backend.client)],
    );
    await tester.pumpAndSettle();
  }

  /// The server goes away, and the next poll finds out.
  Future<void> stopServer(WidgetTester tester) async {
    backend.down = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  group('HomeLayout on a phone', () {
    testWidgets('offers to add a peer on the Peers tab', (tester) async {
      await pumpHome(tester, phoneSize);
      await tester.tap(find.text('Peers'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('stops offering it once the server is unreachable', (tester) async {
      await pumpHome(tester, phoneSize);
      await tester.tap(find.text('Peers'));
      await tester.pumpAndSettle();

      await stopServer(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(ServerConnectionError), findsOneWidget);
    });

    testWidgets('offers it again when the server is back', (tester) async {
      await pumpHome(tester, phoneSize);
      await tester.tap(find.text('Peers'));
      await tester.pumpAndSettle();
      await stopServer(tester);

      backend.down = false;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(ServerConnectionError), findsNothing);
    });
  });

  group('HomeLayout, wide', () {
    testWidgets('shows both columns with their headers', (tester) async {
      await pumpHome(tester, wideSize);

      expect(find.text('Add peer'), findsOneWidget);
      expect(find.text('1/2 online'), findsOneWidget);
      expect(find.text('myawesomelaptop'), findsOneWidget);
    });

    // Each column used to draw its own error, under a header that went on
    // showing the last peer count and device name the server had sent.
    testWidgets('is a single connection error once the server is unreachable', (tester) async {
      await pumpHome(tester, wideSize);

      await stopServer(tester);

      expect(find.byType(ServerConnectionError), findsOneWidget);
      expect(find.text('Add peer'), findsNothing);
      expect(find.text('1/2 online'), findsNothing);
      expect(find.text('myawesomelaptop'), findsNothing);
      // The drawer stays: on Android it is where the server is started from.
      expect(find.text('Overview'), findsOneWidget);
    });

    // Stopping and starting the server by hand means leaving the window twice,
    // and each time the lifecycle pauses polling and resumes it on the way
    // back. The second pause used to find nobody watching the providers, the
    // columns being gone, and polling never came back.
    testWidgets('recovers when the server is stopped and started from another window', (tester) async {
      await pumpHome(tester, wideSize);
      final container = ProviderScope.containerOf(tester.element(find.byType(HomeLayout)));

      Future<void> leaveWindowAnd(void Function() act) async {
        container.read(pollingPolicyProvider.notifier).state = PollingPolicy.paused;
        await tester.pump();
        act();
        container.read(pollingPolicyProvider.notifier).state = PollingPolicy.active;
        await tester.pumpAndSettle();
      }

      await leaveWindowAnd(() => backend.down = true);
      expect(find.byType(ServerConnectionError), findsOneWidget);

      await leaveWindowAnd(() => backend.down = false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(ServerConnectionError), findsNothing);
      expect(find.text('Add peer'), findsOneWidget);
    });
  });
}
