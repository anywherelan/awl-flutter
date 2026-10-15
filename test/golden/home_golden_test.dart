/// Screenshot ("golden") tests for the home screen.
///
/// Pixel comparisons — see the note at the top of
/// `invite_flow_golden_test.dart` on re-shooting them and on reading a CI
/// mismatch.
@Tags(['golden'])
library;

import 'package:anywherelan/entities.dart';
import 'package:anywherelan/main.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop_mobile.dart' as interop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/golden.dart';
import '../helpers/home_backend.dart';
import '../helpers/load_fonts.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

void main() {
  late HomeBackend backend;

  setUpAll(() async {
    registerHttpFallbacks();
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
    // The logo is decoded off the test's fake clock, so settling does not wait
    // for it and the first shot of a run would come out without one.
    await tester.runAsync(
      () => precacheImage(const AssetImage('assets/icons/awl.png'), tester.element(find.byType(HomeLayout))),
    );
    await tester.pumpAndSettle();
  }

  // Both columns and the permanent drawer: the layout a desktop browser gets.
  testWidgets('home, wide layout', (tester) async {
    await pumpHome(tester, wideSize);

    await expectGolden(tester, 'home_wide');
  });

  // A stopped server on Android: one error for the whole screen, and the drawer
  // beside it, which is where the server is started from.
  testWidgets('home, wide layout, server unreachable', (tester) async {
    await pumpHome(tester, wideSize);
    backend.down = true;
    interop.serverRunning = false;
    await tester.pump(const Duration(seconds: 3));

    await expectGolden(tester, 'home_offline_wide');
  });

  testWidgets('home on a phone, Status tab', (tester) async {
    await pumpHome(tester, phoneSize);

    await expectGolden(tester, 'home_phone_status');
  });

  // With an incoming request, listed above the peers as a card of their shape.
  // The black ring around the FAB is its shadow: the test engine paints
  // shadows as solid outlines so that they compare pixel for pixel.
  testWidgets('home on a phone, Peers tab', (tester) async {
    backend.authRequests.add(AuthRequest(otherPeerID, 'pixel-7', '10.66.0.4'));
    await pumpHome(tester, phoneSize);
    await tester.tap(find.text('Peers'));

    await expectGolden(tester, 'home_phone_peers');
  });
}
