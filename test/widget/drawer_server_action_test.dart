/// Android can start and stop awl without the app (Always-on VPN, the VPN
/// being revoked), so the drawer's Stop has to stay a stop whatever happened
/// since it was drawn.
library;

import 'package:anywherelan/drawer.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

const _channel = MethodChannel('anywherelan');

void main() {
  late List<String> calls;
  late Map<String, Object?> alwaysOn;
  late String apiAddress;

  setUp(() {
    calls = [];
    alwaysOn = {'known': true, 'alwaysOn': false, 'lockdown': false, 'routesAllTraffic': false};
    apiAddress = '127.0.0.1:8639';
  });

  Future<void> pumpRunningDrawer(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'start_server':
          return '127.0.0.1:8639';
        case 'server_status':
          return apiAddress;
        case 'always_on_status':
          return alwaysOn;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));

    await initServer();
    calls.clear();
    await pumpAppWidget(tester, const ProviderScope(child: MyDrawer()));
  }

  testWidgets('Stop stops even when Android stopped awl after the drawer was drawn', (tester) async {
    await pumpRunningDrawer(tester);

    apiAddress = '';
    await syncServerState();
    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(calls, contains('stop_server'));
    expect(calls, isNot(contains('start_server')));
  });

  testWidgets('with Always-on VPN, Stop offers the VPN settings instead of stopping', (tester) async {
    alwaysOn['alwaysOn'] = true;
    await pumpRunningDrawer(tester);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Always-on VPN is enabled'), findsOneWidget);

    // Android stops awl while the dialog is open.
    apiAddress = '';
    await syncServerState();
    await tester.tap(find.text('Open VPN settings'));
    await tester.pumpAndSettle();

    expect(calls, contains('open_vpn_settings'));
    expect(calls, isNot(contains('stop_server')));
    expect(calls, isNot(contains('start_server')));
  });

  testWidgets('with Always-on VPN, Cancel leaves awl alone', (tester) async {
    alwaysOn['alwaysOn'] = true;
    await pumpRunningDrawer(tester);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(calls, isNot(contains('stop_server')));
    expect(calls, isNot(contains('open_vpn_settings')));
  });
}
