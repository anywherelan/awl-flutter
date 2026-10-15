/// The two diagnostics screens over a mocked backend: loading, failing to
/// load, and handing what they show to an exporter.
library;

import 'dart:convert';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/diagnostics_screen.dart';
import 'package:anywherelan/file_export.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/diagnostics_backend.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/pump_app.dart';

/// Local wall clock: the file is named after local time.
final _now = DateTime(2026, 4, 10, 9, 5);

/// One call to the exporter.
typedef _Export = ({String name, String text, ExportFormat format});

void main() {
  late DiagnosticsBackend backend;
  late List<_Export> exports;

  setUpAll(registerHttpFallbacks);

  setUp(() {
    backend = DiagnosticsBackend();
    exports = [];
  });

  Future<void> exporter(String name, String text, ExportFormat format) async {
    exports.add((name: name, text: text, format: format));
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await pumpAppWidget(tester, screen, overrides: [httpClientProvider.overrideWithValue(backend.client)]);
    await tester.pumpAndSettle();
  }

  Finder inDialog(Finder finder) => find.descendant(of: find.byType(AlertDialog), matching: finder);

  IconButton exportButton(WidgetTester tester, String tooltip) {
    return tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)),
    );
  }

  group('LogsScreen', () {
    Future<void> pumpLogs(WidgetTester tester) =>
        pumpScreen(tester, LogsScreen(exporter: exporter, now: _now));

    testWidgets('shows the log', (tester) async {
      await pumpLogs(tester);

      expect(find.text(sampleLogs), findsOneWidget);
    });

    testWidgets('asks first, saying what the file gives away', (tester) async {
      await pumpLogs(tester);

      await tester.tap(find.byTooltip('Share logs'));
      await tester.pumpAndSettle();

      expect(inDialog(find.text('Share logs')), findsNWidgets(2));
      expect(
        find.text(
          'The logs may show the names and IP addresses of devices in your network. Only send them to someone you trust.',
        ),
        findsOneWidget,
      );
      expect(exports, isEmpty);
    });

    testWidgets('Cancel exports nothing', (tester) async {
      await pumpLogs(tester);

      await tester.tap(find.byTooltip('Share logs'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.widgetWithText(TextButton, 'Cancel')));
      await tester.pumpAndSettle();

      expect(exports, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('once confirmed, exports the log that is on screen', (tester) async {
      await pumpLogs(tester);
      // The server has moved on since; the file is what the user was reading.
      backend.logs = 'something newer';

      await tester.tap(find.byTooltip('Share logs'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.widgetWithText(TextButton, 'Share logs')));
      await tester.pumpAndSettle();

      expect(exports, [(name: 'awl-logs-20260410-0905', text: sampleLogs, format: ExportFormat.text)]);
    });

    testWidgets('names the file after the server version when it is known', (tester) async {
      await pumpLogs(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(LogsScreen)));
      await tester.runAsync(() => container.read(myPeerInfoProvider.future));

      await tester.tap(find.byTooltip('Share logs'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.widgetWithText(TextButton, 'Share logs')));
      await tester.pumpAndSettle();

      expect(exports.single.name, 'awl-logs-dev-20260410-0905');
    });

    testWidgets('has nothing to export while there is no log', (tester) async {
      backend.logs = '';
      await pumpLogs(tester);

      expect(exportButton(tester, 'Share logs').onPressed, isNull);
    });

    testWidgets('a refusal to export is reported', (tester) async {
      await pumpScreen(
        tester,
        LogsScreen(exporter: (_, _, _) async => throw Exception('no share target'), now: _now),
      );

      await tester.tap(find.byTooltip('Share logs'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(find.widgetWithText(TextButton, 'Share logs')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not export the file'), findsOneWidget);
    });

    // Used to be silence: the request threw and nothing caught it.
    testWidgets('a failed load says so, and Retry loads it', (tester) async {
      backend.down = true;
      await pumpLogs(tester);

      expect(find.text('Failed to load logs: $serverUnreachableMessage'), findsOneWidget);
      expect(exportButton(tester, 'Share logs').onPressed, isNull);

      backend.down = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text(sampleLogs), findsOneWidget);
      expect(find.textContaining('Failed to load logs'), findsNothing);
    });

    testWidgets('a failed refresh keeps the loaded log exportable', (tester) async {
      await pumpLogs(tester);

      backend.down = true;
      await tester.tap(find.byTooltip('Refresh log'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load logs'), findsOneWidget);
      expect(exportButton(tester, 'Share logs').onPressed, isNotNull);
    });
  });

  group('DebugScreen', () {
    Future<void> pumpDebug(WidgetTester tester) =>
        pumpScreen(tester, DebugScreen(exporter: exporter, now: _now));

    testWidgets('exports the debug info as indented JSON, after asking', (tester) async {
      await pumpDebug(tester);

      await tester.tap(find.byTooltip('Share debug info'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This file lists every device in your network with its name and IP addresses. Only send it to someone you trust.',
        ),
        findsOneWidget,
      );
      await tester.tap(inDialog(find.widgetWithText(TextButton, 'Share debug info')));
      await tester.pumpAndSettle();

      final export = exports.single;
      expect(export.name, 'awl-debug-20260410-0905');
      expect(export.format, ExportFormat.json);
      expect(jsonDecode(export.text), jsonDecode(sampleDebugInfo));
      expect(export.text, contains('\n  "General": {'));
    });

    testWidgets('a failed load says so, and Retry loads it', (tester) async {
      backend.down = true;
      await pumpDebug(tester);

      expect(find.text('Failed to load debug info: $serverUnreachableMessage'), findsOneWidget);
      expect(exportButton(tester, 'Share debug info').onPressed, isNull);

      backend.down = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load debug info'), findsNothing);
      expect(exportButton(tester, 'Share debug info').onPressed, isNotNull);
    });
  });
}
