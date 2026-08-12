import 'package:anywherelan/entities.dart';
import 'package:anywherelan/peer_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_reader.dart';
import '../helpers/pump_app.dart';
import '../helpers/samples.dart';

KnownPeerConfig _loadConfig() {
  final json = loadFixtureJson('known_peer_config.json') as Map<String, dynamic>;
  return KnownPeerConfig.fromJson(json);
}

void main() {
  // Tall viewport so the entire form (including the danger zone) fits without scrolling.
  const desktopSize = tallSize;

  group('PeerSettingsView', () {
    testWidgets('renders fields prefilled from KnownPeerConfig', (tester) async {
      final cfg = _loadConfig();
      await pumpAppWidget(tester, PeerSettingsView(peerConfig: cfg), size: desktopSize);

      // The form is rendered.
      expect(find.text('Peer settings'), findsOneWidget);
      expect(find.text('Allow them to use this device as an exit node'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Remove peer'), findsOneWidget);

      // Read-only Name and Peer ID fields show fixture values.
      expect(find.text(cfg.name), findsWidgets);
      expect(find.text(cfg.peerId), findsOneWidget);

      // Editable fields are seeded from the config.
      expect(find.widgetWithText(TextFormField, cfg.alias), findsWidgets);
      expect(find.widgetWithText(TextFormField, cfg.ipAddr), findsOneWidget);

      // Switch reflects the fixture value (false).
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, cfg.weAllowUsingAsExitNode);
    });

    testWidgets('no invite marker for a peer added the usual way', (tester) async {
      await pumpAppWidget(tester, PeerSettingsView(peerConfig: _loadConfig()), size: desktopSize);

      expect(find.textContaining('Added via invite link'), findsNothing);
    });

    testWidgets('invite marker names the link when its label is known', (tester) async {
      final cfg = _loadConfig();
      final invited = KnownPeerConfig(
        cfg.peerId,
        cfg.name,
        cfg.alias,
        cfg.ipAddr,
        cfg.domainName,
        cfg.weAllowUsingAsExitNode,
        '9f3a',
      );

      await pumpAppWidget(
        tester,
        PeerSettingsView(peerConfig: invited, inviteLabel: 'my laptop'),
        size: desktopSize,
      );

      expect(find.text("Added via invite link 'my laptop' (9f3a)"), findsOneWidget);
    });

    testWidgets('invite marker falls back to the id alone', (tester) async {
      final cfg = _loadConfig();
      final invited = KnownPeerConfig(
        cfg.peerId,
        cfg.name,
        cfg.alias,
        cfg.ipAddr,
        cfg.domainName,
        cfg.weAllowUsingAsExitNode,
        '9f3a',
      );

      // Label unknown: the invites list hasn't loaded, or the link had none.
      await pumpAppWidget(tester, PeerSettingsView(peerConfig: invited), size: desktopSize);

      expect(find.text('Added via invite link 9f3a'), findsOneWidget);
    });

    testWidgets('Save changes calls onSave with edited payload', (tester) async {
      final cfg = _loadConfig();
      UpdateKnownPeerConfigRequest? captured;

      await pumpAppWidget(
        tester,
        PeerSettingsView(
          peerConfig: cfg,
          onSave: (payload) async {
            captured = payload;
            return '';
          },
        ),
        size: desktopSize,
      );

      // Toggle the exit-node switch.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.peerID, cfg.peerId);
      expect(captured!.alias, cfg.alias);
      expect(captured!.domainName, cfg.domainName);
      expect(captured!.ipAddr, cfg.ipAddr);
      // Was false in the fixture; flipping the switch should send true.
      expect(captured!.allowUsingAsExitNode, !cfg.weAllowUsingAsExitNode);
    });

    testWidgets('Save changes shows error snackbar when onSave returns error', (tester) async {
      final cfg = _loadConfig();
      await pumpAppWidget(
        tester,
        PeerSettingsView(peerConfig: cfg, onSave: (_) async => 'something broke'),
        size: desktopSize,
      );

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('something broke'), findsOneWidget);
    });

    testWidgets('Remove peer flow: confirm dialog -> onRemove called', (tester) async {
      final cfg = _loadConfig();
      var removeCalls = 0;

      await pumpAppWidget(
        tester,
        PeerSettingsView(
          peerConfig: cfg,
          onRemove: () async {
            removeCalls++;
            return '';
          },
        ),
        size: desktopSize,
      );

      await tester.tap(find.text('Remove peer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('will be removed from your peers list'), findsOneWidget);

      // Confirm. The action keeps its name through the flow, so the screen's
      // button, the dialog title and the confirmation all read "Remove peer" —
      // scope to the dialog.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Remove peer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(removeCalls, 1);
    });

    testWidgets('Remove peer cancel does not invoke onRemove', (tester) async {
      final cfg = _loadConfig();
      var removeCalls = 0;

      await pumpAppWidget(
        tester,
        PeerSettingsView(
          peerConfig: cfg,
          onRemove: () async {
            removeCalls++;
            return '';
          },
        ),
        size: desktopSize,
      );

      await tester.tap(find.text('Remove peer'));
      await tester.pumpAndSettle();

      // Two Cancel TextButtons exist (form bottom bar + dialog) — scope to the dialog.
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextButton, 'Cancel')),
      );
      await tester.pumpAndSettle();

      expect(removeCalls, 0);
    });
  });
}
