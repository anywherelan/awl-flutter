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
const unblockPeerPath = "${v0Prefix}peers/unblock";

const sendFriendRequestPath = "${v0Prefix}peers/invite_peer";
const acceptPeerInvitationPath = "${v0Prefix}peers/accept_peer";
const getAuthRequestsPath = "${v0Prefix}peers/auth_requests";

// Invite links
const createInvitePath = "${v0Prefix}peers/invites/create";
const getInvitesPath = "${v0Prefix}peers/invites/list";
const revokeInvitePath = "${v0Prefix}peers/invites/revoke";

// Settings
const getMyPeerInfoPath = "${v0Prefix}settings/peer_info";
const updateMyInfoPath = "${v0Prefix}settings/update";
const exportServerConfigPath = "${v0Prefix}settings/export_server_config";
const listAvailableProxiesPath = "${v0Prefix}settings/list_proxies";
const updateProxySettingsPath = "${v0Prefix}settings/set_proxy";

// VPN Gateway
const enableVPNGatewayClientPath = "${v0Prefix}vpn_gateway/client/enable";
const disableVPNGatewayClientPath = "${v0Prefix}vpn_gateway/client/disable";
const listAvailableVPNGatewaysPath = "${v0Prefix}vpn_gateway/client/list_available";
const setVPNGatewayServerEnabledPath = "${v0Prefix}vpn_gateway/server/set_enabled";

// Debug
const getP2pDebugInfoPath = "${v0Prefix}debug/p2p_info";
const getDebugLogPath = "${v0Prefix}debug/log";

// Base address of the AWL backend. Set once at startup by platform-specific
// `initApp` code in `server_interop/`; read by [ApiClient] when building each
// request URL.
var serverAddress = "";

/// What a request says when the server did not answer at all. One sentence for
/// every screen, so that a stopped server reads the same wherever it is met.
const serverUnreachableMessage = "Can't reach the server. Make sure it is running and try again.";

/// The request never got an answer: the server is stopped, was never started,
/// or the connection dropped. Its text is [serverUnreachableMessage], ready to
/// be shown as is.
class ServerUnreachable implements Exception {
  const ServerUnreachable();

  @override
  String toString() => serverUnreachableMessage;
}

/// The server answered, and the answer was an error. [message] is its text,
/// ready to be shown as is.
class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

/// How much of an error body that is not the backend's JSON gets shown: enough
/// for the title of a proxy's error page, short enough for a snackbar.
const _errorBodyPreviewLength = 100;

/// HTTP client for the AWL backend REST API.
///
/// Wraps a [http.Client] and exposes one method per endpoint. The duplicated
/// POST-JSON dance (build request → set content-type → send → parse-or-error)
/// is absorbed into [_postJson] / [_postJsonOrError].
class ApiClient {
  ApiClient(this._client);

  final http.Client _client;

  /// Every request builds its URL here, which makes it the one place to notice
  /// that there is no server to send it to yet. Checked rather than left to the
  /// transport, which answers a URL without a host with an [Error].
  Uri _uri(String path) {
    if (serverAddress.isEmpty) throw const ServerUnreachable();
    return Uri.parse(serverAddress + path);
  }

  // ---- GETs ----

  Future<MyPeerInfo> fetchMyPeerInfo() async {
    try {
      final response = await _get(getMyPeerInfoPath);
      final Map<String, dynamic> parsed = jsonDecode(response.body);
      return MyPeerInfo.fromJson(parsed);
    } on ServerUnreachable {
      rethrow;
    } catch (e, s) {
      Error.throwWithStackTrace(Exception('Failed to fetchMyPeerInfo: $e'), s);
    }
  }

  Future<List<KnownPeer>?> fetchKnownPeers() async {
    try {
      final response = await _get(getKnownPeersPath);
      final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();
      return parsed.map<KnownPeer>((json) => KnownPeer.fromJson(json)).toList();
    } on ServerUnreachable {
      rethrow;
    } catch (e, s) {
      Error.throwWithStackTrace(Exception('Failed to fetchKnownPeers: $e'), s);
    }
  }

  Future<ListAvailableProxiesResponse?> fetchAvailableProxies() async {
    try {
      final response = await _get(listAvailableProxiesPath);
      final Map<String, dynamic> parsed = jsonDecode(response.body);
      return ListAvailableProxiesResponse.fromJson(parsed);
    } on ServerUnreachable {
      rethrow;
    } catch (e, s) {
      Error.throwWithStackTrace(Exception('Failed to fetchAvailableProxies: $e'), s);
    }
  }

  Future<ListAvailableVPNGatewaysResponse> fetchAvailableVPNGateways() async {
    try {
      final response = await _get(listAvailableVPNGatewaysPath);
      final Map<String, dynamic> parsed = jsonDecode(response.body);
      return ListAvailableVPNGatewaysResponse.fromJson(parsed);
    } on ServerUnreachable {
      rethrow;
    } catch (e, s) {
      Error.throwWithStackTrace(Exception('Failed to fetchAvailableVPNGateways: $e'), s);
    }
  }

  Future<Map<String, dynamic>?> fetchDebugInfo() async {
    final response = await _get(getP2pDebugInfoPath);
    final parsed = jsonDecode(response.body);
    return parsed;
  }

  Future<String> fetchLogs() async {
    final response = await _get(getDebugLogPath);
    return response.body;
  }

  Future<List<AuthRequest>> fetchAuthRequests() async {
    try {
      final response = await _get(getAuthRequestsPath);
      final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();
      return parsed.map<AuthRequest>((json) => AuthRequest.fromJson(json)).toList();
    } catch (e, s) {
      log('Failed to fetchAuthRequests', error: e, stackTrace: s, name: 'api');
      return [];
    }
  }

  Future<Uint8List> fetchExportedServerConfig() async {
    final response = await _get(exportServerConfigPath);
    return response.bodyBytes;
  }

  Future<List<BlockedPeer>> fetchBlockedPeers() async {
    final response = await _get(getBlockedPeersPath);
    final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();
    return parsed.map<BlockedPeer>((json) => BlockedPeer.fromJson(json)).toList();
  }

  Future<List<Invite>> fetchInvites() async {
    try {
      final response = await _get(getInvitesPath);
      final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();
      return parsed.map<Invite>((json) => Invite.fromJson(json)).toList();
    } on ServerUnreachable {
      rethrow;
    } catch (e, s) {
      Error.throwWithStackTrace(Exception('Failed to fetchInvites: $e'), s);
    }
  }

  // ---- POSTs ----

  Future<String> sendFriendRequest(FriendRequest payload) {
    return _postJsonOrError(sendFriendRequestPath, payload.toJson());
  }

  Future<String> replyFriendRequest(FriendRequestReply payload) {
    return _postJsonOrError(acceptPeerInvitationPath, payload.toJson());
  }

  Future<Invite> createInvite(CreateInviteRequest payload) async {
    final body = await _postJson(createInvitePath, payload.toJson());
    final Map<String, dynamic> parsed = jsonDecode(body);
    return Invite.fromJson(parsed);
  }

  /// Stops new connections through the link; peers already added stay.
  Future<String> revokeInvite(String id) {
    return _postJsonOrError(revokeInvitePath, RevokeInviteRequest(id).toJson());
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

  /// Takes the peer off the blocked list, so its requests are shown again. It
  /// does not add the peer.
  Future<String> unblockPeer(String peerID) {
    return _postJsonOrError(unblockPeerPath, PeerIDRequest(peerID).toJson());
  }

  Future<String> enableVPNGatewayClient(String gatewayPeerID) {
    return _postJsonOrError(enableVPNGatewayClientPath, {"GatewayPeerID": gatewayPeerID});
  }

  Future<String> disableVPNGatewayClient() {
    return _postJsonOrError(disableVPNGatewayClientPath, const {});
  }

  Future<String> setVPNGatewayServerEnabled(bool enabled) {
    return _postJsonOrError(setVPNGatewayServerEnabledPath, {"Enabled": enabled});
  }

  // ---- private helpers ----

  /// Every GET goes through here, so that a server that does not answer is a
  /// [ServerUnreachable] rather than whatever the transport happened to throw.
  Future<http.Response> _get(String path) async {
    final uri = _uri(path);
    try {
      return await _client.get(uri);
    } on http.ClientException {
      throw const ServerUnreachable();
    }
  }

  /// POSTs a JSON payload, returns the raw response body. Throws
  /// [ApiException] with the server's message on non-200, and
  /// [ServerUnreachable] when there was no answer.
  Future<String> _postJson(String path, Map<String, dynamic> payload) async {
    final request = http.Request("POST", _uri(path));
    request.headers["Content-Type"] = "application/json";
    request.body = jsonEncode(payload);

    final int status;
    final String body;
    try {
      final response = await _client.send(request);
      status = response.statusCode;
      body = await response.stream.bytesToString();
    } on http.ClientException {
      throw const ServerUnreachable();
    }
    if (status != 200) throw ApiException(_errorText(status, body));
    return body;
  }

  /// [_postJson] for the mutation endpoints, which hand a string straight to
  /// the UI: "" on success, otherwise the message to show.
  Future<String> _postJsonOrError(String path, Map<String, dynamic> payload) async {
    try {
      await _postJson(path, payload);
      return "";
    } on ApiException catch (e) {
      return e.message;
    } on ServerUnreachable catch (e) {
      return e.toString();
    }
  }

  /// The message of a non-200 response. Never empty: [_postJsonOrError] returns it as is, and "" there
  /// means success. A body that is not the backend's error object (a proxy's error page) is quoted from
  /// its start, since the status code alone rarely says who answered.
  String _errorText(int statusCode, String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final text = ApiError.fromJson(parsed).text;
        return text.isEmpty ? 'HTTP $statusCode' : text;
      }
    } on FormatException {
      // Not JSON.
    }

    final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return 'HTTP $statusCode';
    final preview = text.length > _errorBodyPreviewLength
        ? '${text.substring(0, _errorBodyPreviewLength)}…'
        : text;
    return 'HTTP $statusCode: $preview';
  }
}
