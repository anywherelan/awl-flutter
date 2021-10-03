import 'package:anywherelan/common.dart';
import 'package:json_annotation/json_annotation.dart';

part 'entities.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class KnownPeer {
  final String peerID;
  final String name;
  final String version;
  final String ipAddr;
  final String domainName;
  final bool connected;
  final bool confirmed;
  final bool declined;
  final DateTime lastSeen;
  final List<ConnectionInfo> connections;
  final NetworkStats networkStats;

  KnownPeer(this.peerID, this.name, this.version, this.ipAddr, this.connected, this.confirmed, this.lastSeen,
      this.connections, this.networkStats, this.domainName, this.declined);

  factory KnownPeer.fromJson(Map<String, dynamic> json) => _$KnownPeerFromJson(json);

  Map<String, dynamic> toJson() => _$KnownPeerToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ConnectionInfo {
  final String multiaddr;
  final bool throughRelay;
  final String relayPeerID;
  final String address;
  final String protocol;

  ConnectionInfo(this.multiaddr, this.throughRelay, this.relayPeerID, this.address, this.protocol);

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) => _$ConnectionInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionInfoToJson(this);

  String toString() {
    if (throughRelay) {
      return "through public relay";
    } else if (address.isNotEmpty) {
      return "$protocol $address";
    }

    return multiaddr;
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class MyPeerInfo {
  final String peerID;
  final String name;
  @JsonKey(fromJson: _durationFromNanoseconds, toJson: _durationToNanoseconds)
  final Duration uptime;
  final String serverVersion;
  final NetworkStats networkStats;
  final int totalBootstrapPeers;
  final int connectedBootstrapPeers;
  final String reachability;
  final String awlDNSAddress;
  final bool isAwlDNSSetAsSystem;

  MyPeerInfo(this.peerID, this.name, this.uptime, this.serverVersion, this.networkStats, this.totalBootstrapPeers,
      this.connectedBootstrapPeers, this.reachability, this.awlDNSAddress, this.isAwlDNSSetAsSystem);

  factory MyPeerInfo.fromJson(Map<String, dynamic> json) => _$MyPeerInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MyPeerInfoToJson(this);

  static Duration _durationFromNanoseconds(int milliseconds) => Duration(microseconds: (milliseconds ~/ 1000).toInt());

  static int? _durationToNanoseconds(Duration? duration) => duration == null ? null : duration.inMilliseconds * 1000;
}

@JsonSerializable(fieldRename: FieldRename.pascal)
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

@JsonSerializable(fieldRename: FieldRename.pascal)
class FriendRequest {
  final String peerID;
  final String alias;

  FriendRequest(this.peerID, this.alias);

  factory FriendRequest.fromJson(Map<String, dynamic> json) => _$FriendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FriendRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class FriendRequestReply {
  final String peerID;
  final String alias;
  final bool decline;

  FriendRequestReply(this.peerID, this.alias, this.decline);

  factory FriendRequestReply.fromJson(Map<String, dynamic> json) => _$FriendRequestReplyFromJson(json);

  Map<String, dynamic> toJson() => _$FriendRequestReplyToJson(this);
}

@JsonSerializable()
class ApiError {
  final String error;

  ApiError(this.error);

  factory ApiError.fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);

  Map<String, dynamic> toJson() => _$ApiErrorToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class AuthRequest {
  final String peerID;
  final String name;

  AuthRequest(this.peerID, this.name);

  factory AuthRequest.fromJson(Map<String, dynamic> json) => _$AuthRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AuthRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class PeerIDRequest {
  final String peerID;

  PeerIDRequest(this.peerID);

  factory PeerIDRequest.fromJson(Map<String, dynamic> json) => _$PeerIDRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PeerIDRequestToJson(this);
}

@JsonSerializable()
class KnownPeerConfig {
  final String peerId;
  final String name;
  final String alias;
  final String ipAddr;
  final String domainName;

  KnownPeerConfig(this.peerId, this.name, this.alias, this.ipAddr, this.domainName);

  factory KnownPeerConfig.fromJson(Map<String, dynamic> json) => _$KnownPeerConfigFromJson(json);

  Map<String, dynamic> toJson() => _$KnownPeerConfigToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class UpdateKnownPeerConfigRequest {
  final String peerID;
  final String alias;
  final String domainName;

  UpdateKnownPeerConfigRequest(this.peerID, this.alias, this.domainName);

  factory UpdateKnownPeerConfigRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateKnownPeerConfigRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateKnownPeerConfigRequestToJson(this);
}
