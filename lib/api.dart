import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anywherelan/entities.dart';
import 'package:http/http.dart' as http;

const V0Prefix = "/api/v0/";

// Peers
const GetKnownPeersPath = V0Prefix + "peers/get_known";
const GetKnownPeerSettingsPath = V0Prefix + "peers/get_known_peer_settings";
const UpdatePeerSettingsPath = V0Prefix + "peers/update_settings";
const RemovePeerSettingsPath = V0Prefix + "peers/remove";

const GetBlockedPeersPath = V0Prefix + "peers/get_blocked";

const SendFriendRequestPath = V0Prefix + "peers/invite_peer";
const AcceptPeerInvitationPath = V0Prefix + "peers/accept_peer";
const GetAuthRequestsPath = V0Prefix + "peers/auth_requests";

// Settings
const GetMyPeerInfoPath = V0Prefix + "settings/peer_info";
const UpdateMyInfoPath = V0Prefix + "settings/update";
const ExportServerConfigPath = V0Prefix + "settings/export_server_config";
const ListAvailableProxiesPath = V0Prefix + "settings/list_proxies";
const UpdateProxySettingsPath = V0Prefix + "settings/set_proxy";

// Debug
const GetP2pDebugInfoPath = V0Prefix + "debug/p2p_info";
const GetDebugLogPath = V0Prefix + "debug/log";

var serverAddress = "";

// TODO:
//  try {
//
//  } catch(e) {
//
//  }

Future<MyPeerInfo> fetchMyPeerInfo(http.Client client) async {
  try {
    final response = await client.get(Uri.parse(serverAddress + GetMyPeerInfoPath));
    final Map<String, dynamic> parsed = jsonDecode(response.body);

    return MyPeerInfo.fromJson(parsed);
  } catch (e) {
    print("error in fetchMyPeerInfo: '${e.toString()}'.");
    return MyPeerInfo(
        "", "", Duration.zero, "–", NetworkStats(0, 0, 0, 0), 0, 0, "", "", false, SOCKS5Info("", false, false, "", ""));
  }
}

Future<List<KnownPeer>?> fetchKnownPeers(http.Client client) async {
  try {
    final response = await client.get(Uri.parse(serverAddress + GetKnownPeersPath));
    final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();

    return parsed.map<KnownPeer>((json) => KnownPeer.fromJson(json)).toList();
  } catch (e) {
    print("error in fetchKnownPeers: '${e.toString()}'.");
    return null;
  }
}

Future<ListAvailableProxiesResponse?> fetchAvailableProxies(http.Client client) async {
  try {
    final response = await client.get(Uri.parse(serverAddress + ListAvailableProxiesPath));
    final Map<String, dynamic> parsed = jsonDecode(response.body);

    return ListAvailableProxiesResponse.fromJson(parsed);
  } catch (e) {
    print("error in fetchAvailableProxies: '${e.toString()}'.");
    return null;
  }
}

Future<Map<String, dynamic>?> fetchDebugInfo(http.Client client) async {
  final response = await client.get(Uri.parse(serverAddress + GetP2pDebugInfoPath));
//  final parsed = await compute(jsonDecode, response.body);
  final parsed = jsonDecode(response.body);

  return parsed;
}

Future<String> fetchLogs(http.Client client) async {
  final response = await client.get(Uri.parse(serverAddress + GetDebugLogPath));

  return response.body;
}

Future<List<AuthRequest>> fetchAuthRequests(http.Client client) async {
  try {
    final response = await client.get(Uri.parse(serverAddress + GetAuthRequestsPath));
    final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();

    return parsed.map<AuthRequest>((json) => AuthRequest.fromJson(json)).toList();
  } catch (e) {
    print("error in fetchAuthRequests: '${e.toString()}'.");
    return [];
  }
}

Future<String> sendFriendRequest(http.Client client, String peerID, String alias) async {
  var payload = FriendRequest(peerID, alias);

  var request = http.Request("POST", Uri.parse(serverAddress + SendFriendRequestPath));
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

Future<String> replyFriendRequest(http.Client client, String peerID, String alias, bool decline) async {
  var payload = FriendRequestReply(peerID, alias, decline);

  var request = http.Request("POST", Uri.parse(serverAddress + AcceptPeerInvitationPath));
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
  final response = await client.get(Uri.parse(serverAddress + ExportServerConfigPath));

  return response.bodyBytes;
}

Future<KnownPeerConfig> fetchKnownPeerConfig(http.Client client, String peerID) async {
  var payload = PeerIDRequest(peerID);

  var request = http.Request("POST", Uri.parse(serverAddress + GetKnownPeerSettingsPath));
  request.headers.addAll(<String, String>{"Content-Type": "application/json"});
  request.body = jsonEncode(payload.toJson());

  final response = await client.send(request);
  var responseBody = await response.stream.bytesToString();

  final Map<String, dynamic> parsed = jsonDecode(responseBody);
  return KnownPeerConfig.fromJson(parsed);
}

Future<String> updateKnownPeerConfig(http.Client client, UpdateKnownPeerConfigRequest payload) async {
  var request = http.Request("POST", Uri.parse(serverAddress + UpdatePeerSettingsPath));
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
  var payload = {
    "Name": name,
  };

  var request = http.Request("POST", Uri.parse(serverAddress + UpdateMyInfoPath));
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
  var payload = {
    "UsingPeerID": usingPeerID,
  };

  var request = http.Request("POST", Uri.parse(serverAddress + UpdateProxySettingsPath));
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

  var request = http.Request("POST", Uri.parse(serverAddress + RemovePeerSettingsPath));
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
  final response = await client.get(Uri.parse(serverAddress + GetBlockedPeersPath));
  final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();

  return parsed.map<BlockedPeer>((json) => BlockedPeer.fromJson(json)).toList();
}
