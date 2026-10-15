/// Screenshot ("golden") tests for the diagnostics screens.
///
/// Pixel comparisons — see the note at the top of
/// `invite_flow_golden_test.dart` on re-shooting them and on reading a CI
/// mismatch.
@Tags(['golden'])
library;

import 'package:anywherelan/diagnostics_screen.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/diagnostics_backend.dart';
import '../helpers/golden.dart';
import '../helpers/load_fonts.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

void main() {
  setUpAll(() async {
    registerHttpFallbacks();
    await loadTestFonts();
  });

  // A phone is where the app bar is tight: four actions, and the title has to
  // stay whole beside them.
  testWidgets('server logs on a phone', (tester) async {
    final backend = DiagnosticsBackend();
    await pumpAppWidget(
      tester,
      LogsScreen(exporter: (_, _, _) async {}),
      size: phoneSize,
      overrides: [httpClientProvider.overrideWithValue(backend.client)],
    );

    await expectGolden(tester, 'logs_screen_phone');
  });
}
