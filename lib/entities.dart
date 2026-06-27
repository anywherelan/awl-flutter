import 'package:anywherelan/common.dart';
import 'package:json_annotation/json_annotation.dart';

part 'entities.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class KnownPeer {
  final String peerID;
  final String displayName;
  final String version;
  final String ipAddr;
  final String domainName;
  final bool connected;
  final bool confirmed;
  final bool declined;
  final bool weAllowUsingAsExitNode;
  final bool allowedUsingAsExitNode;
  final bool remoteVPNGatewayServerEnabled;
  final DateTime lastSeen;
  final List<ConnectionInfo> connections;
  final NetworkStats networkStats;
  @JsonKey(fromJson: _durationFromNanoseconds, toJson: _durationToNanoseconds)
  final Duration ping;

  KnownPeer(
    this.peerID,
    this.displayName,
    this.version,
    this.ipAddr,
    this.connected,
    this.confirmed,
    this.lastSeen,
    this.connections,
    this.networkStats,
    this.domainName,
    this.declined,
    this.weAllowUsingAsExitNode,
    this.allowedUsingAsExitNode,
    this.remoteVPNGatewayServerEnabled,
    this.ping,
  );

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

  @override
  String toString() {
    if (throughRelay) {
      return "through public relay";
    } else if (address.isNotEmpty) {
      final host = Uri.parse('my://$address').host;
      return "$host · $protocol";
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
  @JsonKey(name: "SOCKS5")
  final SOCKS5Info socks5;
  @JsonKey(name: "VPNGateway")
  final VPNGatewayInfo vpnGateway;

  MyPeerInfo(
    this.peerID,
    this.name,
    this.uptime,
    this.serverVersion,
    this.networkStats,
    this.totalBootstrapPeers,
    this.connectedBootstrapPeers,
    this.reachability,
    this.awlDNSAddress,
    this.isAwlDNSSetAsSystem,
    this.socks5,
    this.vpnGateway,
  );

  factory MyPeerInfo.fromJson(Map<String, dynamic> json) => _$MyPeerInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MyPeerInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SOCKS5Info {
  final String listenAddress;
  final bool proxyingEnabled;
  final bool listenerEnabled;
  final bool connected;
  final String usingPeerID;
  final String usingPeerName;
  final String usingPeerPublicIP;
  @JsonKey(fromJson: _durationFromNanoseconds, toJson: _durationToNanoseconds)
  final Duration usingPeerPing;
  final bool usingPeerThroughRelay;

  SOCKS5Info(
    this.listenAddress,
    this.proxyingEnabled,
    this.listenerEnabled,
    this.connected,
    this.usingPeerID,
    this.usingPeerName,
    this.usingPeerPublicIP,
    this.usingPeerPing,
    this.usingPeerThroughRelay,
  );

  factory SOCKS5Info.fromJson(Map<String, dynamic> json) => _$SOCKS5InfoFromJson(json);

  Map<String, dynamic> toJson() => _$SOCKS5InfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class VPNGatewayInfo {
  final bool clientEnabled;
  final bool serverEnabled;
  final String gatewayPeerID;
  final String gatewayPeerName;
  final bool connected;
  final String gatewayPublicIP;
  @JsonKey(fromJson: _durationFromNanoseconds, toJson: _durationToNanoseconds)
  final Duration gatewayPing;
  final bool gatewayThroughRelay;

  VPNGatewayInfo(
    this.clientEnabled,
    this.gatewayPeerID,
    this.gatewayPeerName,
    this.connected,
    this.serverEnabled,
    this.gatewayPublicIP,
    this.gatewayPing,
    this.gatewayThroughRelay,
  );

  factory VPNGatewayInfo.fromJson(Map<String, dynamic> json) => _$VPNGatewayInfoFromJson(json);

  Map<String, dynamic> toJson() => _$VPNGatewayInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class AvailableVPNGateway {
  final String peerID;
  final String peerName;
  final bool connected;

  AvailableVPNGateway(this.peerID, this.peerName, this.connected);

  factory AvailableVPNGateway.fromJson(Map<String, dynamic> json) => _$AvailableVPNGatewayFromJson(json);

  Map<String, dynamic> toJson() => _$AvailableVPNGatewayToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ListAvailableVPNGatewaysResponse {
  @JsonKey(name: "VPNGateways", defaultValue: <AvailableVPNGateway>[])
  final List<AvailableVPNGateway> vpnGateways;

  ListAvailableVPNGatewaysResponse(this.vpnGateways);

  factory ListAvailableVPNGatewaysResponse.fromJson(Map<String, dynamic> json) =>
      _$ListAvailableVPNGatewaysResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListAvailableVPNGatewaysResponseToJson(this);
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
  final String ipAddr;

  FriendRequest(this.peerID, this.alias, this.ipAddr);

  factory FriendRequest.fromJson(Map<String, dynamic> json) => _$FriendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FriendRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ListAvailableProxiesResponse {
  final List<AvailableProxy> proxies;

  ListAvailableProxiesResponse(this.proxies);

  factory ListAvailableProxiesResponse.fromJson(Map<String, dynamic> json) =>
      _$ListAvailableProxiesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListAvailableProxiesResponseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class AvailableProxy {
  final String peerID;
  final String peerName;
  final bool connected;

  AvailableProxy(this.peerID, this.peerName, this.connected);

  factory AvailableProxy.fromJson(Map<String, dynamic> json) => _$AvailableProxyFromJson(json);

  Map<String, dynamic> toJson() => _$AvailableProxyToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class FriendRequestReply {
  final String peerID;
  final String alias;
  final bool decline;
  final String ipAddr;

  FriendRequestReply(this.peerID, this.alias, this.decline, this.ipAddr);

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
  final String suggestedIP;

  AuthRequest(this.peerID, this.name, this.suggestedIP);

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
  final bool weAllowUsingAsExitNode;

  KnownPeerConfig(
    this.peerId,
    this.name,
    this.alias,
    this.ipAddr,
    this.domainName,
    this.weAllowUsingAsExitNode,
  );

  factory KnownPeerConfig.fromJson(Map<String, dynamic> json) => _$KnownPeerConfigFromJson(json);

  Map<String, dynamic> toJson() => _$KnownPeerConfigToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class UpdateKnownPeerConfigRequest {
  final String peerID;
  final String alias;
  final String domainName;
  final String ipAddr;
  final bool allowUsingAsExitNode;

  UpdateKnownPeerConfigRequest(
    this.peerID,
    this.alias,
    this.domainName,
    this.ipAddr,
    this.allowUsingAsExitNode,
  );

  factory UpdateKnownPeerConfigRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateKnownPeerConfigRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateKnownPeerConfigRequestToJson(this);
}

@JsonSerializable()
class BlockedPeer {
  final String peerId;
  final String displayName;
  final DateTime createdAt;

  BlockedPeer(this.peerId, this.displayName, this.createdAt);

  factory BlockedPeer.fromJson(Map<String, dynamic> json) => _$BlockedPeerFromJson(json);

  Map<String, dynamic> toJson() => _$BlockedPeerToJson(this);
}

Duration _durationFromNanoseconds(int nanoseconds) => Duration(microseconds: (nanoseconds ~/ 1000).toInt());

int? _durationToNanoseconds(Duration? duration) => duration == null ? null : duration.inMicroseconds * 1000;
