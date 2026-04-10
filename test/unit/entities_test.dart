import 'dart:convert';

import 'package:anywherelan/entities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_reader.dart';

/// Round-trips a JSON-serializable object the same way production code does:
/// `toJson` produces a Map that may still contain nested model objects;
/// `jsonEncode` walks the tree and calls each `toJson` recursively;
/// `jsonDecode` then yields a plain Map suitable for `fromJson`. Calling
/// `fromJson(toJson(obj))` directly does NOT work for models with nested
/// objects unless `explicitToJson: true` is set on the annotation, which it
/// isn't here — so always go through `jsonEncode`/`jsonDecode`.
Map<String, dynamic> jsonRoundtrip(Object toJsonOutput) {
  return jsonDecode(jsonEncode(toJsonOutput)) as Map<String, dynamic>;
}

void main() {
  group('MyPeerInfo', () {
    test('parses captured fixture', () {
      final json = loadFixtureJson('my_peer_info.json') as Map<String, dynamic>;
      final info = MyPeerInfo.fromJson(json);

      expect(info.peerID, '12D3KooWPxx4CkH2AL45tzKUR2g6Ht55g82eFuSMevAximtCQfwR');
      expect(info.name, 'myawesomelaptop');
      expect(info.serverVersion, 'dev');
      expect(info.totalBootstrapPeers, 5);
      expect(info.connectedBootstrapPeers, 4);
      expect(info.reachability, 'Unknown');
      expect(info.awlDNSAddress, '127.0.0.66:53');
      expect(info.isAwlDNSSetAsSystem, isTrue);
      expect(info.networkStats.totalIn, 147875);
      expect(info.networkStats.totalOut, 132478);
      expect(info.socks5.listenAddress, '127.0.0.66:8080');
      expect(info.socks5.proxyingEnabled, isTrue);
      expect(info.socks5.listenerEnabled, isTrue);
      expect(info.socks5.usingPeerName, 'awl-tester');
    });

    test('decodes Uptime nanoseconds into Duration', () {
      // Fixture: "Uptime": 9190163479 ns = 9_190_163 microseconds
      final json = loadFixtureJson('my_peer_info.json') as Map<String, dynamic>;
      final info = MyPeerInfo.fromJson(json);

      expect(info.uptime, const Duration(microseconds: 9190163));
    });

    test('round-trips through Dart model', () {
      final json = loadFixtureJson('my_peer_info.json') as Map<String, dynamic>;
      final original = MyPeerInfo.fromJson(json);
      final reparsed = MyPeerInfo.fromJson(jsonRoundtrip(original.toJson()));

      expect(reparsed.peerID, original.peerID);
      expect(reparsed.name, original.name);
      expect(reparsed.uptime, original.uptime);
      expect(reparsed.serverVersion, original.serverVersion);
      expect(reparsed.networkStats.totalIn, original.networkStats.totalIn);
      expect(reparsed.networkStats.rateOut, original.networkStats.rateOut);
      expect(reparsed.socks5.usingPeerID, original.socks5.usingPeerID);
    });
  });

  group('KnownPeer', () {
    test('parses captured fixture list', () {
      final list = loadFixtureJson('known_peers.json') as List<dynamic>;
      final peers = list.cast<Map<String, dynamic>>().map(KnownPeer.fromJson).toList();

      expect(peers, hasLength(greaterThanOrEqualTo(1)));
      final first = peers.first;
      expect(first.peerID, isNotEmpty);
      expect(first.connections, isNotEmpty);
      expect(first.connections.first.protocol, isNotEmpty);
      expect(first.networkStats.totalIn, isNonNegative);
    });

    test('decodes Ping nanoseconds into Duration', () {
      // The first peer in the fixture has a ping field in nanoseconds.
      final list = loadFixtureJson('known_peers.json') as List<dynamic>;
      final rawFirst = list.first as Map<String, dynamic>;
      final pingNs = rawFirst['Ping'] as int;
      final peer = KnownPeer.fromJson(rawFirst);

      // Converter: ns → microseconds (truncating divide by 1000)
      expect(peer.ping.inMicroseconds, pingNs ~/ 1000);
    });

    test('round-trips through Dart model', () {
      final list = loadFixtureJson('known_peers.json') as List<dynamic>;
      for (final raw in list.cast<Map<String, dynamic>>()) {
        final original = KnownPeer.fromJson(raw);
        final reparsed = KnownPeer.fromJson(jsonRoundtrip(original.toJson()));
        expect(reparsed.peerID, original.peerID);
        expect(reparsed.displayName, original.displayName);
        expect(reparsed.connected, original.connected);
        expect(reparsed.ping, original.ping);
        expect(reparsed.connections.length, original.connections.length);
      }
    });
  });

  group('ListAvailableProxiesResponse', () {
    test('parses captured fixture', () {
      final json = loadFixtureJson('available_proxies.json') as Map<String, dynamic>;
      final resp = ListAvailableProxiesResponse.fromJson(json);
      expect(resp.proxies, isA<List<AvailableProxy>>());
    });
  });

  group('AuthRequest', () {
    test('parses sample fixture and round-trips', () {
      final list = loadFixtureJson('auth_requests_sample.json') as List<dynamic>;
      final reqs = list.cast<Map<String, dynamic>>().map(AuthRequest.fromJson).toList();

      expect(reqs, hasLength(1));
      expect(reqs.first.name, 'incoming-friend');
      expect(reqs.first.suggestedIP, '10.66.0.42');

      final round = AuthRequest.fromJson(reqs.first.toJson());
      expect(round.peerID, reqs.first.peerID);
      expect(round.name, reqs.first.name);
      expect(round.suggestedIP, reqs.first.suggestedIP);
    });

    test('parses empty live fixture', () {
      final list = loadFixtureJson('auth_requests.json') as List<dynamic>;
      expect(list, isEmpty);
    });
  });

  group('BlockedPeer', () {
    test('parses sample fixture and round-trips', () {
      final list = loadFixtureJson('blocked_peers_sample.json') as List<dynamic>;
      final blocked = list.cast<Map<String, dynamic>>().map(BlockedPeer.fromJson).toList();

      expect(blocked, hasLength(1));
      expect(blocked.first.displayName, 'blocked-peer');

      final round = BlockedPeer.fromJson(blocked.first.toJson());
      expect(round.peerId, blocked.first.peerId);
      expect(round.displayName, blocked.first.displayName);
      expect(round.createdAt, blocked.first.createdAt);
    });
  });

  group('KnownPeerConfig', () {
    test('parses captured fixture (camelCase keys)', () {
      final json = loadFixtureJson('known_peer_config.json') as Map<String, dynamic>;
      final cfg = KnownPeerConfig.fromJson(json);

      expect(cfg.peerId, isNotEmpty);
      expect(cfg.name, 'awl-tester');
      expect(cfg.alias, 'awl-tester');
      expect(cfg.ipAddr, '10.66.0.2');
      expect(cfg.domainName, 'awl-tester');
      expect(cfg.weAllowUsingAsExitNode, isFalse);
    });

    test('round-trips through Dart model', () {
      final json = loadFixtureJson('known_peer_config.json') as Map<String, dynamic>;
      final original = KnownPeerConfig.fromJson(json);
      final reparsed = KnownPeerConfig.fromJson(original.toJson());

      expect(reparsed.peerId, original.peerId);
      expect(reparsed.name, original.name);
      expect(reparsed.alias, original.alias);
      expect(reparsed.ipAddr, original.ipAddr);
      expect(reparsed.domainName, original.domainName);
      expect(reparsed.weAllowUsingAsExitNode, original.weAllowUsingAsExitNode);
    });
  });

  group('Constructed-only models', () {
    test('FriendRequest round-trip', () {
      final original = FriendRequest('peer-id-1', 'alias-1', '10.0.0.1');
      final round = FriendRequest.fromJson(original.toJson());
      expect(round.peerID, 'peer-id-1');
      expect(round.alias, 'alias-1');
      expect(round.ipAddr, '10.0.0.1');
    });

    test('FriendRequestReply round-trip', () {
      final original = FriendRequestReply('peer-id-1', 'alias-1', true, '10.0.0.1');
      final round = FriendRequestReply.fromJson(original.toJson());
      expect(round.peerID, 'peer-id-1');
      expect(round.alias, 'alias-1');
      expect(round.decline, isTrue);
      expect(round.ipAddr, '10.0.0.1');
    });

    test('PeerIDRequest round-trip', () {
      final original = PeerIDRequest('peer-id-1');
      final round = PeerIDRequest.fromJson(original.toJson());
      expect(round.peerID, 'peer-id-1');
    });

    test('UpdateKnownPeerConfigRequest round-trip', () {
      final original = UpdateKnownPeerConfigRequest('peer-id-1', 'alias-1', 'domain-1', '10.0.0.1', true);
      final round = UpdateKnownPeerConfigRequest.fromJson(original.toJson());
      expect(round.peerID, 'peer-id-1');
      expect(round.alias, 'alias-1');
      expect(round.domainName, 'domain-1');
      expect(round.ipAddr, '10.0.0.1');
      expect(round.allowUsingAsExitNode, isTrue);
    });

    test('ApiError round-trip', () {
      final original = ApiError('something failed');
      final round = ApiError.fromJson(original.toJson());
      expect(round.error, 'something failed');
    });
  });
}
