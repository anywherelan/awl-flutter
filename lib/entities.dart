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

  /// Set when we let this peer in through one of our invite links; empty otherwise.
  /// Non-secret marker, kept forever by the backend.
  final String inviteID;
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
    this.inviteID,
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

  /// Let the peer use us as an exit node right away, instead of a second trip through peer settings.
  final bool allowUsingAsExitNode;

  /// Bearer token from an invite link. The backend stores it with the peer and
  /// presents it in every auth request until the peer confirms us — which it
  /// then does without anyone pressing accept.
  final String token;

  FriendRequest(this.peerID, this.alias, this.ipAddr, {this.allowUsingAsExitNode = false, this.token = ''});

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

  final bool allowUsingAsExitNode;

  FriendRequestReply(this.peerID, this.alias, this.decline, this.ipAddr, {this.allowUsingAsExitNode = false});

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

  /// See [KnownPeer.inviteID]. Omitted by the backend when empty.
  @JsonKey(defaultValue: '')
  final String inviteID;

  KnownPeerConfig(
    this.peerId,
    this.name,
    this.alias,
    this.ipAddr,
    this.domainName,
    this.weAllowUsingAsExitNode,
    this.inviteID,
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

/// One invite link, as returned by `peers/invites/list` and `.../create`.
///
/// The token is never returned on its own — only inside [link], which is what
/// the user shares.
@JsonSerializable(fieldRename: FieldRename.pascal)
class Invite {
  @JsonKey(name: 'ID')
  final String id;
  final String label;

  /// Rebuilt by the backend on every request from the current node name, so
  /// renaming this device changes the link shown here while links already
  /// handed out keep working — the name plays no part in validation.
  final String link;

  /// Alias to give the peer that redeems this link. Single-use links only.
  final String alias;
  final bool allowUsingAsExitNode;
  final int maxUses;
  final int usedCount;

  /// Go's zero time ([zeroGoTime]) means the invite never expires.
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool revoked;

  /// One of [inviteStatusActive], [inviteStatusExpired], [inviteStatusUsedUp],
  /// [inviteStatusRevoked] — derived by the backend for display.
  final String status;

  Invite(
    this.id,
    this.label,
    this.link,
    this.alias,
    this.allowUsingAsExitNode,
    this.maxUses,
    this.usedCount,
    this.expiresAt,
    this.createdAt,
    this.revoked,
    this.status,
  );

  factory Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);

  Map<String, dynamic> toJson() => _$InviteToJson(this);

  bool get expires => expiresAt.isAfter(zeroGoTime);

  bool get isActive => status == inviteStatusActive;
}

const inviteStatusActive = 'active';
const inviteStatusExpired = 'expired';
const inviteStatusUsedUp = 'used_up';
const inviteStatusRevoked = 'revoked';

@JsonSerializable(fieldRename: FieldRename.pascal)
class CreateInviteRequest {
  /// 0 means the backend default, 1 (single-use).
  final int maxUses;

  /// 0 means the invite never expires. A number rather than a duration string,
  /// as with the backend's other duration params.
  final int expiresInSeconds;

  /// Only accepted for single-use invites — aliases must be unique.
  final String alias;
  final bool allowUsingAsExitNode;
  final String label;

  CreateInviteRequest({
    this.maxUses = 1,
    this.expiresInSeconds = 0,
    this.alias = '',
    this.allowUsingAsExitNode = false,
    this.label = '',
  });

  factory CreateInviteRequest.fromJson(Map<String, dynamic> json) => _$CreateInviteRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateInviteRequestToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class RevokeInviteRequest {
  @JsonKey(name: 'ID')
  final String id;

  RevokeInviteRequest(this.id);

  factory RevokeInviteRequest.fromJson(Map<String, dynamic> json) => _$RevokeInviteRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RevokeInviteRequestToJson(this);
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
