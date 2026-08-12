/// Screenshot ("golden") tests for the two dialogs that carry no invite link
/// and so are not part of `invite_flow_golden_test.dart`.
///
/// They exist because the modal-unification pass rebuilt both — `SimpleDialog`
/// with a hand-rolled button row became an `AlertDialog` with its buttons in
/// `actions:`, at the one width all form dialogs share — and neither had any
/// test to notice if the shape came out wrong.
///
/// See the header of `invite_flow_golden_test.dart` for how to run and re-shoot
/// these.
@Tags(['golden'])
library;

import 'package:anywherelan/entities.dart';
import 'package:anywherelan/notifications.dart';
import 'package:anywherelan/status_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/golden.dart';
import '../helpers/load_fonts.dart';
import '../helpers/samples.dart';

const _peerID = otherPeerID;

/// Stands in for `_BeGatewaySwitch`, which the real dialog is handed rather
/// than builds: it applies its own state through its own endpoint and reads
/// Riverpod. Shaped like it, so the screenshot shows the row's true height and
/// alignment against the field above.
///
/// `onChanged` is a no-op rather than null on purpose: null renders the row
/// greyed out, which is what the real one looks like only on an Android build
/// without VPN support.
final _gatewayTile = SwitchListTile(
  contentPadding: EdgeInsets.zero,
  value: false,
  onChanged: (_) {},
  title: const Text('Serve as VPN Gateway'),
  subtitle: const Text('Let permitted devices route their internet traffic through this device.'),
);

void main() {
  setUpAll(loadTestFonts);

  const wide = Size(900, 1000);

  testWidgets('incoming friend request', (tester) async {
    await goldenOfDialog(tester, wide, 'auth_request_dialog', (context) {
      showDialog<void>(
        context: context,
        builder: (_) => AuthRequestDialogView(
          request: AuthRequest(_peerID, 'vasya-laptop', '10.66.0.7'),
          onSubmit: (_) async => '',
        ),
      );
    });
  });

  testWidgets('this device settings', (tester) async {
    await goldenOfDialog(tester, wide, 'settings_dialog', (context) {
      showDialog<void>(
        context: context,
        builder: (_) => SettingsDialogView(
          initialName: 'my-laptop',
          gatewayTile: _gatewayTile,
          onSubmit: (_) async => '',
        ),
      );
    });
  });
}
