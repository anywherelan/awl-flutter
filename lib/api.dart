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

var serverAddress = "";

Future<MyPeerInfo> fetchMyPeerInfo(http.Client client) async {
  try {
    final response = await client.get(Uri.parse(serverAddress + getMyPeerInfoPath));
    final Map<String, dynamic> parsed = jsonDecode(response.body);

    return MyPeerInfo.fromJson(parsed);
  } catch (e, s) {
    Error.throwWithStackTrace(Exception('Failed to fetchMyPeerInfo: $e'), s);
  }
}

Future<List<KnownPeer>?> fetchKnownPeers(http.Client client) async {
  try {
    final response = await client.get(Uri.parse(serverAddress + getKnownPeersPath));
    final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();

    return parsed.map<KnownPeer>((json) => KnownPeer.fromJson(json)).toList();
  } catch (e, s) {
    Error.throwWithStackTrace(Exception('Failed to fetchKnownPeers: $e'), s);
  }
}

Future<ListAvailableProxiesResponse?> fetchAvailableProxies(http.Client client) async {
  try {
    final response = await client.get(Uri.parse(serverAddress + listAvailableProxiesPath));
    final Map<String, dynamic> parsed = jsonDecode(response.body);

    return ListAvailableProxiesResponse.fromJson(parsed);
  } catch (e, s) {
    Error.throwWithStackTrace(Exception('Failed to fetchAvailableProxies: $e'), s);
  }
}

Future<Map<String, dynamic>?> fetchDebugInfo(http.Client client) async {
  final response = await client.get(Uri.parse(serverAddress + getP2pDebugInfoPath));
  //  final parsed = await compute(jsonDecode, response.body);
  final parsed = jsonDecode(response.body);

  return parsed;
}

Future<String> fetchLogs(http.Client client) async {
  final response = await client.get(Uri.parse(serverAddress + getDebugLogPath));

  return response.body;
}

Future<List<AuthRequest>> fetchAuthRequests(http.Client client) async {
  try {
    final response = await client.get(Uri.parse(serverAddress + getAuthRequestsPath));
    final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();

    return parsed.map<AuthRequest>((json) => AuthRequest.fromJson(json)).toList();
  } catch (e, s) {
    log('Failed to fetchAuthRequests', error: e, stackTrace: s, name: 'api');
    return [];
  }
}

Future<String> sendFriendRequest(http.Client client, String peerID, String alias, String ipAddr) async {
  var payload = FriendRequest(peerID, alias, ipAddr);

  var request = http.Request("POST", Uri.parse(serverAddress + sendFriendRequestPath));
  request.headers.addAll(<String, String>{"Content-Type": "application/json"});
  request.body = jsonEncode(payload.toJson());

  final response = await client.send(request);
  var responseBody = await response.stream.bytesToString();
  if (response.statusCode != 200) {
    final Map<String, dynamic> parsed = jsonDecode(responseBody);
    return ApiError.fromJson(parsed).error;
  }

  return "";
}

Future<String> replyFriendRequest(
  http.Client client,
  String peerID,
  String alias,
  bool decline,
  String ipAddr,
) async {
  var payload = FriendRequestReply(peerID, alias, decline, ipAddr);

  var request = http.Request("POST", Uri.parse(serverAddress + acceptPeerInvitationPath));
  request.headers.addAll(<String, String>{"Content-Type": "application/json"});
  request.body = jsonEncode(payload.toJson());

  final response = await client.send(request);
  var responseBody = await response.stream.bytesToString();
  if (response.statusCode != 200) {
    final Map<String, dynamic> parsed = jsonDecode(responseBody);
    return ApiError.fromJson(parsed).error;
  }

  return "";
}

Future<Uint8List> fetchExportedServerConfig(http.Client client) async {
  final response = await client.get(Uri.parse(serverAddress + exportServerConfigPath));

  return response.bodyBytes;
}

Future<KnownPeerConfig> fetchKnownPeerConfig(http.Client client, String peerID) async {
  var payload = PeerIDRequest(peerID);

  var request = http.Request("POST", Uri.parse(serverAddress + getKnownPeerSettingsPath));
  request.headers.addAll(<String, String>{"Content-Type": "application/json"});
  request.body = jsonEncode(payload.toJson());

  final response = await client.send(request);
  var responseBody = await response.stream.bytesToString();
  if (response.statusCode != 200) {
    final Map<String, dynamic> parsed = jsonDecode(responseBody);
    throw Exception(ApiError.fromJson(parsed).error);
  }

  final Map<String, dynamic> parsed = jsonDecode(responseBody);
  return KnownPeerConfig.fromJson(parsed);
}

Future<String> updateKnownPeerConfig(http.Client client, UpdateKnownPeerConfigRequest payload) async {
  var request = http.Request("POST", Uri.parse(serverAddress + updatePeerSettingsPath));
  request.headers.addAll(<String, String>{"Content-Type": "application/json"});
  request.body = jsonEncode(payload.toJson());

  final response = await client.send(request);
  var responseBody = await response.stream.bytesToString();
  if (response.statusCode != 200) {
    final Map<String, dynamic> parsed = jsonDecode(responseBody);
    return ApiError.fromJson(parsed).error;
  }

  return "";
}

Future<String> updateMySettings(http.Client client, String name) async {
  var payload = {"Name": name};

  var request = http.Request("POST", Uri.parse(serverAddress + updateMyInfoPath));
  request.headers.addAll(<String, String>{"Content-Type": "application/json"});
  request.body = jsonEncode(payload);

  final response = await client.send(request);
  var responseBody = await response.stream.bytesToString();
  if (response.statusCode != 200) {
    final Map<String, dynamic> parsed = jsonDecode(responseBody);
    return ApiError.fromJson(parsed).error;
  }

  return "";
}

Future<String> updateProxySettings(http.Client client, String usingPeerID) async {
  var payload = {"UsingPeerID": usingPeerID};

  var request = http.Request("POST", Uri.parse(serverAddress + updateProxySettingsPath));
  request.headers.addAll(<String, String>{"Content-Type": "application/json"});
  request.body = jsonEncode(payload);

  final response = await client.send(request);
  var responseBody = await response.stream.bytesToString();
  if (response.statusCode != 200) {
    final Map<String, dynamic> parsed = jsonDecode(responseBody);
    return ApiError.fromJson(parsed).error;
  }

  return "";
}

Future<String> removePeer(http.Client client, String peerID) async {
  var payload = PeerIDRequest(peerID);

  var request = http.Request("POST", Uri.parse(serverAddress + removePeerSettingsPath));
  request.headers.addAll(<String, String>{"Content-Type": "application/json"});
  request.body = jsonEncode(payload.toJson());

  final response = await client.send(request);
  var responseBody = await response.stream.bytesToString();
  if (response.statusCode != 200) {
    final Map<String, dynamic> parsed = jsonDecode(responseBody);
    return ApiError.fromJson(parsed).error;
  }

  return "";
}

Future<List<BlockedPeer>> fetchBlockedPeers(http.Client client) async {
  final response = await client.get(Uri.parse(serverAddress + getBlockedPeersPath));
  final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();

  return parsed.map<BlockedPeer>((json) => BlockedPeer.fromJson(json)).toList();
}
