import 'package:anywherelan/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Short on purpose: these tests are about which buttons the field carries, not
/// about how a 95-character link wraps, and without [loadTestFonts] a long
/// value would overflow on the test engine's box glyphs for reasons the app
/// never has.
const _value = 'awl://invite?p=abc';

void main() {
  Future<void> pumpField(WidgetTester tester, {VoidCallback? onShare}) {
    return pumpAppWidget(
      tester,
      CopyableField(
        value: _value,
        copiedMessage: 'Link copied to clipboard',
        tooltip: 'Copy link',
        onShare: onShare,
        shareTooltip: 'Share link',
      ),
    );
  }

  testWidgets('carries no share button unless it is given something to share', (tester) async {
    await pumpField(tester);

    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    // The Peer ID fields are the reason this is optional: a bare peer id is not
    // a thing the receiving app can act on.
    expect(find.byIcon(Icons.share), findsNothing);
  });

  testWidgets('shares from inside the field, beside Copy', (tester) async {
    var shared = 0;
    await pumpField(tester, onShare: () => shared++);

    // Both buttons belong to the field itself — Share used to sit outside it,
    // which left the field narrower than the one stacked under it.
    final buttons = find.descendant(of: find.byType(CopyableField), matching: find.byType(IconButton));
    expect(buttons, findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.share));
    await tester.pump();
    expect(shared, 1);
  });

  testWidgets('says the copy failed instead of confirming one that did not happen', (tester) async {
    // What the web build over plain HTTP does when the browser refuses: the
    // button used to leave no trace at all, the throw going nowhere.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'copy_fail', message: 'Clipboard is not available in the context.');
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpField(tester);
    await tester.tap(find.byIcon(Icons.content_copy));
    await tester.pump();

    expect(find.text(copyFailedMessage), findsOneWidget);
    expect(find.text('Link copied to clipboard'), findsNothing);
    // No tick either: it is the same claim of success in another form.
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('copies the value and says so, share or no share', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpField(tester, onShare: () {});
    await tester.tap(find.byIcon(Icons.content_copy));
    await tester.pump();

    expect(copied, _value);
    expect(find.text('Link copied to clipboard'), findsOneWidget);
    // The tick replaces the copy icon for two seconds; let its timer run out.
    await tester.pump(const Duration(seconds: 3));
  });
}
