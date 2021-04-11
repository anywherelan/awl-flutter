import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:anywherelan/entities.dart';
import 'dart:async';

const V0Prefix = "/api/v0/";

// Peers
const GetKnownPeersPath = V0Prefix + "peers/get_known";
const GetKnownPeerSettingsPath = V0Prefix + "peers/get_known_peer_settings";

const SendFriendRequestPath = V0Prefix + "peers/invite_peer";
const AcceptPeerInvitationPath = V0Prefix + "peers/accept_peer";
const UpdatePeerSettingsPath = V0Prefix + "peers/update_settings";
const GetAuthRequestsPath = V0Prefix + "peers/auth_requests";

// Settings
const GetMyPeerInfoPath = V0Prefix + "settings/peer_info";
const UpdateMyInfoPath = V0Prefix + "settings/update";
const ExportServerConfigPath = V0Prefix + "settings/export_server_config";

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
  final response = await client.get(Uri.parse(serverAddress + GetMyPeerInfoPath));
  final Map<String, dynamic> parsed = jsonDecode(response.body);

  return MyPeerInfo.fromJson(parsed);
}

Future<List<KnownPeer>?> fetchKnownPeers(http.Client client) async {
  final response = await client.get(Uri.parse(serverAddress + GetKnownPeersPath));
  final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();

  return parsed.map<KnownPeer>((json) => KnownPeer.fromJson(json)).toList();
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
  final response = await client.get(Uri.parse(serverAddress + GetAuthRequestsPath));
  final parsed = jsonDecode(response.body).cast<Map<String, dynamic>>();

  return parsed.map<AuthRequest>((json) => AuthRequest.fromJson(json)).toList();
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

Future<String?> acceptFriendRequest(http.Client client, String peerID, String alias) async {
  var payload = FriendRequest(peerID, alias);

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

Future<String> fetchExportedServerConfig(http.Client client) async {
  final response = await client.get(Uri.parse(serverAddress + ExportServerConfigPath));

  return response.body;
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

Future<String?> updateKnownPeerConfig(http.Client client, UpdateKnownPeerConfigRequest payload) async {
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

Future<String?> updateMySettings(http.Client client, String name) async {
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
