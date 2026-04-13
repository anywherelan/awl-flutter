import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:anywherelan/entities.dart';
import 'package:http/http.dart' as http;

const v0Prefix = "/api/v0/";

// Peers
const getKnownPeersPath = "${v0Prefix}peers/get_known";
const getKnownPeerSettingsPath = "${v0Prefix}peers/get_known_peer_settings";
const updatePeerSettingsPath = "${v0Prefix}peers/update_settings";
const removePeerSettingsPath = "${v0Prefix}peers/remove";

const getBlockedPeersPath = "${v0Prefix}peers/get_blocked";

const sendFriendRequestPath = "${v0Prefix}peers/invite_peer";
const acceptPeerInvitationPath = "${v0Prefix}peers/accept_peer";
const getAuthRequestsPath = "${v0Prefix}peers/auth_requests";

// Settings
const getMyPeerInfoPath = "${v0Prefix}settings/peer_info";
const updateMyInfoPath = "${v0Prefix}settings/update";
const exportServerConfigPath = "${v0Prefix}settings/export_server_config";
const listAvailableProxiesPath = "${v0Prefix}settings/list_proxies";
const updateProxySettingsPath = "${v0Prefix}settings/set_proxy";

// Debug
const getP2pDebugInfoPath = "${v0Prefix}debug/p2p_info";
const getDebugLogPath = "${v0Prefix}debug/log";

// Base address of the AWL backend. Set once at startup by platform-specific
// `initApp` code in `server_interop/`; read by [ApiClient] when building each
// request URL.
var serverAddress = "";

/// HTTP client for the AWL backend REST API.
///
/// Wraps a [http.Client] and exposes one method per endpoint. The duplicated
/// POST-JSON dance (build request → set content-type → send → parse-or-error)
/// is absorbed into [_postJson] / [_postJsonOrError].
class ApiClient {
  ApiClient(this._client);

  final http.Client _client;

  Uri _uri(String path) => Uri.parse(serverAddress + path);

  // ---- GETs ----

  Future<MyPeerInfo> fetchMyPeerInfo() async {
    try {
      final response = await _client.get(_uri(getMyPeerInfoPath));
      final Map<String, dynamic> parsed = jsonDecode(response.body);
      return MyPeerInfo.fromJson(parsed);
    } catch (e, s) {
      Error.throwWithStackTrace(Exception('Failed to fetchMyPeerInfo: $e'), s);
    }
  }

  Future<List<KnownPeer>?> fetchKnownPeers() async {
    try {
      final response = await _client.get(_uri(getKnownPeersPath));
      final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();
      return parsed.map<KnownPeer>((json) => KnownPeer.fromJson(json)).toList();
    } catch (e, s) {
      Error.throwWithStackTrace(Exception('Failed to fetchKnownPeers: $e'), s);
    }
  }

  Future<ListAvailableProxiesResponse?> fetchAvailableProxies() async {
    try {
      final response = await _client.get(_uri(listAvailableProxiesPath));
      final Map<String, dynamic> parsed = jsonDecode(response.body);
      return ListAvailableProxiesResponse.fromJson(parsed);
    } catch (e, s) {
      Error.throwWithStackTrace(Exception('Failed to fetchAvailableProxies: $e'), s);
    }
  }

  Future<Map<String, dynamic>?> fetchDebugInfo() async {
    final response = await _client.get(_uri(getP2pDebugInfoPath));
    final parsed = jsonDecode(response.body);
    return parsed;
  }

  Future<String> fetchLogs() async {
    final response = await _client.get(_uri(getDebugLogPath));
    return response.body;
  }

  Future<List<AuthRequest>> fetchAuthRequests() async {
    try {
      final response = await _client.get(_uri(getAuthRequestsPath));
      final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();
      return parsed.map<AuthRequest>((json) => AuthRequest.fromJson(json)).toList();
    } catch (e, s) {
      log('Failed to fetchAuthRequests', error: e, stackTrace: s, name: 'api');
      return [];
    }
  }

  Future<Uint8List> fetchExportedServerConfig() async {
    final response = await _client.get(_uri(exportServerConfigPath));
    return response.bodyBytes;
  }

  Future<List<BlockedPeer>> fetchBlockedPeers() async {
    final response = await _client.get(_uri(getBlockedPeersPath));
    final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();
    return parsed.map<BlockedPeer>((json) => BlockedPeer.fromJson(json)).toList();
  }

  // ---- POSTs ----

  Future<String> sendFriendRequest(String peerID, String alias, String ipAddr) {
    return _postJsonOrError(sendFriendRequestPath, FriendRequest(peerID, alias, ipAddr).toJson());
  }

  Future<String> replyFriendRequest(String peerID, String alias, bool decline, String ipAddr) {
    return _postJsonOrError(
      acceptPeerInvitationPath,
      FriendRequestReply(peerID, alias, decline, ipAddr).toJson(),
    );
  }

  Future<KnownPeerConfig> fetchKnownPeerConfig(String peerID) async {
    final body = await _postJson(getKnownPeerSettingsPath, PeerIDRequest(peerID).toJson());
    final Map<String, dynamic> parsed = jsonDecode(body);
    return KnownPeerConfig.fromJson(parsed);
  }

  Future<String> updateKnownPeerConfig(UpdateKnownPeerConfigRequest payload) {
    return _postJsonOrError(updatePeerSettingsPath, payload.toJson());
  }

  Future<String> updateMySettings(String name) {
    return _postJsonOrError(updateMyInfoPath, {"Name": name});
  }

  Future<String> updateProxySettings(String usingPeerID) {
    return _postJsonOrError(updateProxySettingsPath, {"UsingPeerID": usingPeerID});
  }

  Future<String> removePeer(String peerID) {
    return _postJsonOrError(removePeerSettingsPath, PeerIDRequest(peerID).toJson());
  }

  // ---- private helpers ----

  /// POSTs a JSON payload, returns the raw response body. Throws on non-200
  /// with the server's [ApiError.error] as the exception message.
  Future<String> _postJson(String path, Map<String, dynamic> payload) async {
    final request = http.Request("POST", _uri(path));
    request.headers["Content-Type"] = "application/json";
    request.body = jsonEncode(payload);

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      final Map<String, dynamic> parsed = jsonDecode(body);
      throw Exception(ApiError.fromJson(parsed).error);
    }
    return body;
  }

  /// POSTs a JSON payload, returns "" on success or the server's
  /// [ApiError.error] string on non-200. Matches the existing convention for
  /// mutation endpoints that want to surface the error string to the UI
  /// instead of throwing.
  Future<String> _postJsonOrError(String path, Map<String, dynamic> payload) async {
    final request = http.Request("POST", _uri(path));
    request.headers["Content-Type"] = "application/json";
    request.body = jsonEncode(payload);

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      final Map<String, dynamic> parsed = jsonDecode(body);
      return ApiError.fromJson(parsed).error;
    }
    return "";
  }
}
