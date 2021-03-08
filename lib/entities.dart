import 'package:json_annotation/json_annotation.dart';
import 'package:peerlanflutter/common.dart';

part 'entities.g.dart';

@JsonSerializable(nullable: false, fieldRename: FieldRename.pascal)
class KnownPeer {
  final String peerID;
  final String name;
  final String version;
  final String ipAddr;
  final bool connected;
  final bool confirmed;
  final DateTime lastSeen;
  final List<String> addresses;
  final NetworkStats networkStats;
  final List<int> allowedLocalPorts;
  final List<int> allowedRemotePorts;

  KnownPeer(this.peerID, this.name, this.version, this.ipAddr, this.connected, this.confirmed, this.lastSeen,
      this.addresses, this.networkStats, this.allowedLocalPorts, this.allowedRemotePorts);

  factory KnownPeer.fromJson(Map<String, dynamic> json) => _$KnownPeerFromJson(json);

  Map<String, dynamic> toJson() => _$KnownPeerToJson(this);
}

@JsonSerializable(nullable: false, fieldRename: FieldRename.pascal)
class MyPeerInfo {
  final String peerID;
  final String name;
  @JsonKey(fromJson: _durationFromNanoseconds, toJson: _durationToNanoseconds)
  final Duration uptime;
  final String serverVersion;
  final NetworkStats networkStats;
  final int totalBootstrapPeers;
  final int connectedBootstrapPeers;

  MyPeerInfo(this.peerID, this.name, this.uptime, this.serverVersion, this.networkStats, this.totalBootstrapPeers,
      this.connectedBootstrapPeers);

  factory MyPeerInfo.fromJson(Map<String, dynamic> json) => _$MyPeerInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MyPeerInfoToJson(this);

  static Duration _durationFromNanoseconds(int milliseconds) =>
      milliseconds == null ? null : Duration(microseconds: (milliseconds ~/ 1000).toInt());

  static int _durationToNanoseconds(Duration duration) => duration == null ? null : duration.inMilliseconds * 1000;
}

@JsonSerializable(nullable: false, fieldRename: FieldRename.pascal)
class NetworkStats {
  final int totalIn;
  final int totalOut;
  final double rateIn;
  final double rateOut;

  NetworkStats(this.totalIn, this.totalOut, this.rateIn, this.rateOut);

  factory NetworkStats.fromJson(Map<String, dynamic> json) => _$NetworkStatsFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkStatsToJson(this);

  String inAsString() {
    return formatNetworkStats(totalIn, rateIn);
  }

  String outAsString() {
    return formatNetworkStats(totalOut, rateOut);
  }
}

@JsonSerializable(nullable: false, fieldRename: FieldRename.pascal)
class FriendRequest {
  final String peerID;
  final String alias;

  FriendRequest(this.peerID, this.alias);

  factory FriendRequest.fromJson(Map<String, dynamic> json) => _$FriendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FriendRequestToJson(this);
}

@JsonSerializable(nullable: false)
class ApiError {
  final String error;

  ApiError(this.error);

  factory ApiError.fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);

  Map<String, dynamic> toJson() => _$ApiErrorToJson(this);
}

@JsonSerializable(nullable: false, fieldRename: FieldRename.pascal)
class AuthRequest {
  final String peerID;
  final String name;

  AuthRequest(this.peerID, this.name);

  factory AuthRequest.fromJson(Map<String, dynamic> json) => _$AuthRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AuthRequestToJson(this);
}

@JsonSerializable(nullable: false, fieldRename: FieldRename.pascal)
class PeerIDRequest {
  final String peerID;

  PeerIDRequest(this.peerID);

  factory PeerIDRequest.fromJson(Map<String, dynamic> json) => _$PeerIDRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PeerIDRequestToJson(this);
}

@JsonSerializable(nullable: false)
class KnownPeerConfig {
  final String peerId;
  final String name;
  final String alias;
  final String ipAddr;
  final Map<int, LocalConnConfig> allowedLocalPorts;
  final Map<int, RemoteConnConfig> allowedRemotePorts;

  KnownPeerConfig(this.peerId, this.name, this.alias, this.ipAddr, this.allowedLocalPorts, this.allowedRemotePorts);

  factory KnownPeerConfig.fromJson(Map<String, dynamic> json) => _$KnownPeerConfigFromJson(json);

  Map<String, dynamic> toJson() => _$KnownPeerConfigToJson(this);
}

@JsonSerializable(nullable: false, fieldRename: FieldRename.pascal)
class UpdateKnownPeerConfigRequest {
  final String peerID;
  final String alias;
  final Map<int, LocalConnConfig> localConns;
  final Map<int, RemoteConnConfig> remoteConns;

  UpdateKnownPeerConfigRequest(this.peerID, this.alias, this.localConns, this.remoteConns);

  factory UpdateKnownPeerConfigRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateKnownPeerConfigRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateKnownPeerConfigRequestToJson(this);
}

@JsonSerializable(nullable: false)
class LocalConnConfig {
  final int port;
  final String description;

  LocalConnConfig(this.port, this.description);

  factory LocalConnConfig.fromJson(Map<String, dynamic> json) => _$LocalConnConfigFromJson(json);

  Map<String, dynamic> toJson() => _$LocalConnConfigToJson(this);
}

@JsonSerializable(nullable: false)
class RemoteConnConfig {
  final int remotePort;
  final int mappedLocalPort;
  final bool forwarded;

//  final String protocol;
  final String description;

  RemoteConnConfig(this.remotePort, this.mappedLocalPort, this.forwarded, this.description);

  factory RemoteConnConfig.fromJson(Map<String, dynamic> json) => _$RemoteConnConfigFromJson(json);

  Map<String, dynamic> toJson() => _$RemoteConnConfigToJson(this);
}

@JsonSerializable(nullable: false, fieldRename: FieldRename.pascal)
class ForwardedPort {
  final int remotePort;
  final String listenAddress;
  final String peerID;
  final String protocol;

  ForwardedPort(this.remotePort, this.listenAddress, this.peerID, this.protocol);

  factory ForwardedPort.fromJson(Map<String, dynamic> json) => _$ForwardedPortFromJson(json);

  Map<String, dynamic> toJson() => _$ForwardedPortToJson(this);
}
