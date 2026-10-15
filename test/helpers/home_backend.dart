import 'dart:convert';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop_mobile.dart' as interop;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../fixtures/fixture_reader.dart';
import 'mock_http_client.dart';

/// The backend behind the home screen, as far as its four polled endpoints go:
/// answers from the fixtures until [down] is set, then refuses every
/// connection the way a stopped server does.
///
/// Create it in `setUp`: it also puts back the globals the home screen reads
/// (`serverAddress`, `isServerAvailable`, the running flag behind the drawer),
/// which would otherwise leak from one test into the next.
class HomeBackend {
  final client = MockHttpClient();
  bool down = false;

  HomeBackend() {
    serverAddress = 'http://test.local';
    isServerAvailable.value = true;
    interop.serverRunning = true;
    addTearDown(() {
      isServerAvailable.value = true;
      interop.serverRunning = false;
    });

    when(() => client.get(any())).thenAnswer((invocation) async {
      final uri = invocation.positionalArguments.single as Uri;
      if (down) throw http.ClientException('Connection refused', uri);
      return http.Response(
        _body(uri.path),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  String _body(String path) {
    switch (path) {
      case getMyPeerInfoPath:
        return loadFixture('my_peer_info.json');
      case getKnownPeersPath:
        return jsonEncode(_knownPeers());
      case listAvailableProxiesPath:
        return loadFixture('available_proxies.json');
      case listAvailableVPNGatewaysPath:
        return '{"VPNGateways": []}';
    }
    throw StateError('unexpected GET $path');
  }

  /// The fixture's one connected peer, and a second that has not accepted us
  /// yet. Neither prints a "last seen", which is measured from the real clock.
  List<Map<String, dynamic>> _knownPeers() {
    final connected = (loadFixtureJson('known_peers.json') as List<dynamic>).cast<Map<String, dynamic>>();
    final pending = Map<String, dynamic>.of(connected.first)
      ..['PeerID'] = '12D3KooWMASi45ub7Qe4ZE36UT5G6cU4ud8Fhhe4deS4F3cw9KTA'
      ..['Name'] = 'maxbook'
      ..['DisplayName'] = 'maxbook'
      ..['Alias'] = 'maxbook'
      ..['DomainName'] = 'maxbook'
      ..['Connected'] = false
      ..['Confirmed'] = false;
    return [...connected, pending];
  }
}
