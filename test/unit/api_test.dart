import 'dart:async';
import 'dart:convert';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../fixtures/fixture_reader.dart';
import '../helpers/mock_http_client.dart';

const _baseUrl = 'http://test.local';

http.StreamedResponse _streamed(String body, int status) {
  return http.StreamedResponse(Stream.value(utf8.encode(body)), status);
}

void main() {
  setUpAll(() {
    registerHttpFallbacks();
  });

  late MockHttpClient client;
  late ApiClient api;

  setUp(() {
    client = MockHttpClient();
    api = ApiClient(client);
    serverAddress = _baseUrl;
  });

  group('GET endpoints', () {
    test('fetchMyPeerInfo parses fixture', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => http.Response(loadFixture('my_peer_info.json'), 200));

      final info = await api.fetchMyPeerInfo();

      expect(info.peerID, isNotEmpty);
      expect(info.serverVersion, 'dev');
      verify(() => client.get(Uri.parse('$_baseUrl$getMyPeerInfoPath'))).called(1);
    });

    test('fetchMyPeerInfo throws on malformed JSON', () async {
      when(() => client.get(any())).thenAnswer((_) async => http.Response('not json', 200));

      await expectLater(api.fetchMyPeerInfo(), throwsA(isA<Exception>()));
    });

    test('fetchKnownPeers parses fixture list', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => http.Response(loadFixture('known_peers.json'), 200));

      final peers = await api.fetchKnownPeers();

      expect(peers, isNotNull);
      expect(peers!, hasLength(greaterThanOrEqualTo(1)));
      expect(peers.first.peerID, isNotEmpty);
      verify(() => client.get(Uri.parse('$_baseUrl$getKnownPeersPath'))).called(1);
    });

    test('fetchKnownPeers throws on malformed JSON', () async {
      when(() => client.get(any())).thenAnswer((_) async => http.Response('garbage', 200));

      await expectLater(api.fetchKnownPeers(), throwsA(isA<Exception>()));
    });

    test('fetchAvailableProxies parses fixture', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => http.Response(loadFixture('available_proxies.json'), 200));

      final resp = await api.fetchAvailableProxies();

      expect(resp, isNotNull);
      expect(resp!.proxies, isA<List<AvailableProxy>>());
      verify(() => client.get(Uri.parse('$_baseUrl$listAvailableProxiesPath'))).called(1);
    });

    test('fetchAuthRequests returns empty list on empty fixture', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => http.Response(loadFixture('auth_requests.json'), 200));

      final reqs = await api.fetchAuthRequests();
      expect(reqs, isEmpty);
    });

    test('fetchAuthRequests parses sample fixture', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => http.Response(loadFixture('auth_requests_sample.json'), 200));

      final reqs = await api.fetchAuthRequests();
      expect(reqs, hasLength(1));
      expect(reqs.first.name, 'incoming-friend');
    });

    test('fetchAuthRequests returns empty list on error (does not throw)', () async {
      // Documented behavior in lib/api.dart: errors are logged and an empty
      // list is returned, which keeps the notifications poller from crashing
      // the UI when the server is unreachable.
      when(() => client.get(any())).thenAnswer((_) async => http.Response('not json', 200));

      final reqs = await api.fetchAuthRequests();
      expect(reqs, isEmpty);
    });

    test('fetchBlockedPeers parses sample fixture', () async {
      when(
        () => client.get(any()),
      ).thenAnswer((_) async => http.Response(loadFixture('blocked_peers_sample.json'), 200));

      final blocked = await api.fetchBlockedPeers();
      expect(blocked, hasLength(1));
      expect(blocked.first.displayName, 'blocked-peer');
    });

    test('fetchDebugInfo parses arbitrary JSON', () async {
      when(() => client.get(any())).thenAnswer((_) async => http.Response('{"foo": "bar", "n": 42}', 200));

      final result = await api.fetchDebugInfo();
      expect(result, isNotNull);
      expect(result!['foo'], 'bar');
      expect(result['n'], 42);
      verify(() => client.get(Uri.parse('$_baseUrl$getP2pDebugInfoPath'))).called(1);
    });

    test('fetchLogs returns the response body verbatim', () async {
      when(() => client.get(any())).thenAnswer((_) async => http.Response('line1\nline2\n', 200));

      final logs = await api.fetchLogs();
      expect(logs, 'line1\nline2\n');
    });

    test('fetchExportedServerConfig returns body bytes', () async {
      final bytes = [0x42, 0x00, 0xFF, 0x10];
      when(() => client.get(any())).thenAnswer((_) async => http.Response.bytes(bytes, 200));

      final result = await api.fetchExportedServerConfig();
      expect(result, bytes);
    });
  });

  group('POST endpoints', () {
    test('sendFriendRequest returns empty string on success', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('', 200));

      final result = await api.sendFriendRequest('pid', 'alias', '10.0.0.1');
      expect(result, '');

      final captured = verify(() => client.send(captureAny())).captured.single as http.Request;
      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$_baseUrl$sendFriendRequestPath');
      expect(captured.headers['Content-Type'], 'application/json');
      final decoded = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(decoded['PeerID'], 'pid');
      expect(decoded['Alias'], 'alias');
      expect(decoded['IpAddr'], '10.0.0.1');
    });

    test('sendFriendRequest returns ApiError.error on non-200', () async {
      when(
        () => client.send(any()),
      ).thenAnswer((_) async => _streamed('{"error": "boom", "message": ""}', 400));

      final result = await api.sendFriendRequest('pid', 'alias', '10.0.0.1');
      expect(result, 'boom');
    });

    test('replyFriendRequest sends decline flag and POSTs to accept_peer', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('', 200));

      final result = await api.replyFriendRequest('pid', 'alias', true, '10.0.0.1');
      expect(result, '');

      final captured = verify(() => client.send(captureAny())).captured.single as http.Request;
      expect(captured.url.toString(), '$_baseUrl$acceptPeerInvitationPath');
      final decoded = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(decoded['Decline'], true);
    });

    test('replyFriendRequest returns error on non-200', () async {
      when(
        () => client.send(any()),
      ).thenAnswer((_) async => _streamed('{"error": "nope", "message": ""}', 500));

      final result = await api.replyFriendRequest('pid', 'alias', false, '10.0.0.1');
      expect(result, 'nope');
    });

    test('fetchKnownPeerConfig parses JSON on success', () async {
      when(
        () => client.send(any()),
      ).thenAnswer((_) async => _streamed(loadFixture('known_peer_config.json'), 200));

      final cfg = await api.fetchKnownPeerConfig('some-peer-id');
      expect(cfg.name, 'awl-tester');
      expect(cfg.alias, 'awl-tester');
    });

    test('fetchKnownPeerConfig throws ApiError on non-200', () async {
      when(
        () => client.send(any()),
      ).thenAnswer((_) async => _streamed('{"error": "peer not found", "message": ""}', 404));

      await expectLater(
        api.fetchKnownPeerConfig('missing'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'toString', contains('peer not found'))),
      );
    });

    test('updateKnownPeerConfig sends payload and returns empty on success', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('', 200));

      final payload = UpdateKnownPeerConfigRequest('pid', 'alias', 'domain', '10.0.0.1', true);
      final result = await api.updateKnownPeerConfig(payload);
      expect(result, '');

      final captured = verify(() => client.send(captureAny())).captured.single as http.Request;
      expect(captured.url.toString(), '$_baseUrl$updatePeerSettingsPath');
      final decoded = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(decoded['PeerID'], 'pid');
      expect(decoded['Alias'], 'alias');
      expect(decoded['DomainName'], 'domain');
      expect(decoded['AllowUsingAsExitNode'], true);
    });

    test('updateKnownPeerConfig returns error on non-200', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('{"error": "invalid"}', 422));

      final payload = UpdateKnownPeerConfigRequest('pid', 'alias', 'domain', '10.0.0.1', true);
      final result = await api.updateKnownPeerConfig(payload);
      expect(result, 'invalid');
    });

    test('updateMySettings sends Name and returns empty on success', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('', 200));

      final result = await api.updateMySettings('newname');
      expect(result, '');

      final captured = verify(() => client.send(captureAny())).captured.single as http.Request;
      expect(captured.url.toString(), '$_baseUrl$updateMyInfoPath');
      final decoded = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(decoded['Name'], 'newname');
    });

    test('updateMySettings returns error on non-200', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('{"error": "name taken"}', 409));

      final result = await api.updateMySettings('newname');
      expect(result, 'name taken');
    });

    test('updateProxySettings sends UsingPeerID and returns empty on success', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('', 200));

      final result = await api.updateProxySettings('exit-peer-id');
      expect(result, '');

      final captured = verify(() => client.send(captureAny())).captured.single as http.Request;
      expect(captured.url.toString(), '$_baseUrl$updateProxySettingsPath');
      final decoded = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(decoded['UsingPeerID'], 'exit-peer-id');
    });

    test('updateProxySettings returns error on non-200', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('{"error": "no such peer"}', 404));

      final result = await api.updateProxySettings('pid');
      expect(result, 'no such peer');
    });

    test('removePeer sends PeerID and returns empty on success', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('', 200));

      final result = await api.removePeer('pid');
      expect(result, '');

      final captured = verify(() => client.send(captureAny())).captured.single as http.Request;
      expect(captured.url.toString(), '$_baseUrl$removePeerSettingsPath');
      final decoded = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(decoded['PeerID'], 'pid');
    });

    test('removePeer returns error on non-200', () async {
      when(() => client.send(any())).thenAnswer((_) async => _streamed('{"error": "cannot remove"}', 500));

      final result = await api.removePeer('pid');
      expect(result, 'cannot remove');
    });
  });
}
