/// The settings screen is reachable with the server stopped, so what it offers
/// there has to hold up without one.
library;

import 'package:anywherelan/api.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockHttpClient client;

  setUpAll(registerHttpFallbacks);

  setUp(() {
    client = MockHttpClient();
    serverAddress = 'http://test.local';
    isServerAvailable.value = true;
    addTearDown(() => isServerAvailable.value = true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpAppWidget(
      tester,
      const AppSettingsScreen(),
      overrides: [httpClientProvider.overrideWithValue(client)],
    );
    await tester.pumpAndSettle();
  }

  ListTile exportTile(WidgetTester tester) {
    return tester.widget<ListTile>(find.widgetWithText(ListTile, 'Export settings'));
  }

  group('AppSettingsScreen', () {
    testWidgets('export is on offer while the server answers', (tester) async {
      await pumpScreen(tester);

      expect(exportTile(tester).enabled, isTrue);
      expect(find.text('Needs a running server.'), findsNothing);
    });

    testWidgets('export is off, and says why, once the server is unreachable', (tester) async {
      await pumpScreen(tester);

      isServerAvailable.value = false;
      await tester.pump();

      expect(exportTile(tester).enabled, isFalse);
      expect(find.text('Needs a running server.'), findsOneWidget);
    });

    // The flag only follows the polled endpoints, so a server can be gone
    // before it says so. The request used to run outside the `try`.
    testWidgets('a failed export is reported', (tester) async {
      when(() => client.get(any())).thenThrow(http.ClientException('Connection refused'));
      await pumpScreen(tester);

      await tester.tap(find.text('Export settings'));
      await tester.pumpAndSettle();

      expect(find.textContaining(serverUnreachableMessage), findsOneWidget);
    });
  });
}
