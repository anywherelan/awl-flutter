import 'package:anywherelan/file_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diagnosticsFileName', () {
    // Local wall clock: the name is for the person who saved the file.
    final now = DateTime(2026, 10, 13, 9, 7);

    test('says what it is, which version wrote it and when', () {
      expect(diagnosticsFileName('logs', version: 'v0.18.0', now: now), 'awl-logs-v0.18.0-20261013-0907');
    });

    test('leaves the version out when it is not known', () {
      expect(diagnosticsFileName('debug', now: now), 'awl-debug-20261013-0907');
      expect(diagnosticsFileName('debug', version: '', now: now), 'awl-debug-20261013-0907');
    });

    test('keeps only what is safe in a file name', () {
      expect(
        diagnosticsFileName('logs', version: 'v0.18.0 (dirty)/x', now: now),
        'awl-logs-v0.18.0dirtyx-20261013-0907',
      );
    });
  });
}
