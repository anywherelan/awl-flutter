// GENERATED CODE - DO NOT MODIFY BY HAND

// dart format off

part of 'entities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KnownPeer _$KnownPeerFromJson(Map<String, dynamic> json) => KnownPeer(
  json['PeerID'] as String,
  json['DisplayName'] as String,
  json['Version'] as String,
  json['IpAddr'] as String,
  json['Connected'] as bool,
  json['Confirmed'] as bool,
  DateTime.parse(json['LastSeen'] as String),
  (json['Connections'] as List<dynamic>)
      .map((e) => ConnectionInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  NetworkStats.fromJson(json['NetworkStats'] as Map<String, dynamic>),
  json['DomainName'] as String,
  json['Declined'] as bool,
  json['WeAllowUsingAsExitNode'] as bool,
  json['AllowedUsingAsExitNode'] as bool,
  json['RemoteVPNGatewayServerEnabled'] as bool,
  _durationFromNanoseconds((json['Ping'] as num).toInt()),
  json['InviteID'] as String,
);

Map<String, dynamic> _$KnownPeerToJson(KnownPeer instance) => <String, dynamic>{
  'PeerID': instance.peerID,
  'DisplayName': instance.displayName,
  'Version': instance.version,
  'IpAddr': instance.ipAddr,
  'DomainName': instance.domainName,
  'Connected': instance.connected,
  'Confirmed': instance.confirmed,
  'Declined': instance.declined,
  'WeAllowUsingAsExitNode': instance.weAllowUsingAsExitNode,
  'AllowedUsingAsExitNode': instance.allowedUsingAsExitNode,
  'RemoteVPNGatewayServerEnabled': instance.remoteVPNGatewayServerEnabled,
  'InviteID': instance.inviteID,
  'LastSeen': instance.lastSeen.toIso8601String(),
  'Connections': instance.connections,
  'NetworkStats': instance.networkStats,
  'Ping': _durationToNanoseconds(instance.ping),
};

ConnectionInfo _$ConnectionInfoFromJson(Map<String, dynamic> json) =>
    ConnectionInfo(
      json['Multiaddr'] as String,
      json['ThroughRelay'] as bool,
      json['RelayPeerID'] as String,
      json['Address'] as String,
      json['Protocol'] as String,
    );

Map<String, dynamic> _$ConnectionInfoToJson(ConnectionInfo instance) =>
    <String, dynamic>{
      'Multiaddr': instance.multiaddr,
      'ThroughRelay': instance.throughRelay,
      'RelayPeerID': instance.relayPeerID,
      'Address': instance.address,
      'Protocol': instance.protocol,
    };

MyPeerInfo _$MyPeerInfoFromJson(Map<String, dynamic> json) => MyPeerInfo(
  json['PeerID'] as String,
  json['Name'] as String,
  _durationFromNanoseconds((json['Uptime'] as num).toInt()),
  json['ServerVersion'] as String,
  NetworkStats.fromJson(json['NetworkStats'] as Map<String, dynamic>),
  (json['TotalBootstrapPeers'] as num).toInt(),
  (json['ConnectedBootstrapPeers'] as num).toInt(),
  json['Reachability'] as String,
  json['AwlDNSAddress'] as String,
  json['IsAwlDNSSetAsSystem'] as bool,
  SOCKS5Info.fromJson(json['SOCKS5'] as Map<String, dynamic>),
  VPNGatewayInfo.fromJson(json['VPNGateway'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MyPeerInfoToJson(MyPeerInfo instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Name': instance.name,
      'Uptime': _durationToNanoseconds(instance.uptime),
      'ServerVersion': instance.serverVersion,
      'NetworkStats': instance.networkStats,
      'TotalBootstrapPeers': instance.totalBootstrapPeers,
      'ConnectedBootstrapPeers': instance.connectedBootstrapPeers,
      'Reachability': instance.reachability,
      'AwlDNSAddress': instance.awlDNSAddress,
      'IsAwlDNSSetAsSystem': instance.isAwlDNSSetAsSystem,
      'SOCKS5': instance.socks5,
      'VPNGateway': instance.vpnGateway,
    };

SOCKS5Info _$SOCKS5InfoFromJson(Map<String, dynamic> json) => SOCKS5Info(
  json['ListenAddress'] as String,
  json['ProxyingEnabled'] as bool,
  json['ListenerEnabled'] as bool,
  json['Connected'] as bool,
  json['UsingPeerID'] as String,
  json['UsingPeerName'] as String,
  json['UsingPeerPublicIP'] as String,
  _durationFromNanoseconds((json['UsingPeerPing'] as num).toInt()),
  json['UsingPeerThroughRelay'] as bool,
);

Map<String, dynamic> _$SOCKS5InfoToJson(SOCKS5Info instance) =>
    <String, dynamic>{
      'ListenAddress': instance.listenAddress,
      'ProxyingEnabled': instance.proxyingEnabled,
      'ListenerEnabled': instance.listenerEnabled,
      'Connected': instance.connected,
      'UsingPeerID': instance.usingPeerID,
      'UsingPeerName': instance.usingPeerName,
      'UsingPeerPublicIP': instance.usingPeerPublicIP,
      'UsingPeerPing': _durationToNanoseconds(instance.usingPeerPing),
      'UsingPeerThroughRelay': instance.usingPeerThroughRelay,
    };

VPNGatewayInfo _$VPNGatewayInfoFromJson(Map<String, dynamic> json) =>
    VPNGatewayInfo(
      json['ClientEnabled'] as bool,
      json['GatewayPeerID'] as String,
      json['GatewayPeerName'] as String,
      json['Connected'] as bool,
      json['ServerEnabled'] as bool,
      json['GatewayPublicIP'] as String,
      _durationFromNanoseconds((json['GatewayPing'] as num).toInt()),
      json['GatewayThroughRelay'] as bool,
    );

Map<String, dynamic> _$VPNGatewayInfoToJson(VPNGatewayInfo instance) =>
    <String, dynamic>{
      'ClientEnabled': instance.clientEnabled,
      'ServerEnabled': instance.serverEnabled,
      'GatewayPeerID': instance.gatewayPeerID,
      'GatewayPeerName': instance.gatewayPeerName,
      'Connected': instance.connected,
      'GatewayPublicIP': instance.gatewayPublicIP,
      'GatewayPing': _durationToNanoseconds(instance.gatewayPing),
      'GatewayThroughRelay': instance.gatewayThroughRelay,
    };

AvailableVPNGateway _$AvailableVPNGatewayFromJson(Map<String, dynamic> json) =>
    AvailableVPNGateway(
      json['PeerID'] as String,
      json['PeerName'] as String,
      json['Connected'] as bool,
    );

Map<String, dynamic> _$AvailableVPNGatewayToJson(
  AvailableVPNGateway instance,
) => <String, dynamic>{
  'PeerID': instance.peerID,
  'PeerName': instance.peerName,
  'Connected': instance.connected,
};

ListAvailableVPNGatewaysResponse _$ListAvailableVPNGatewaysResponseFromJson(
  Map<String, dynamic> json,
) => ListAvailableVPNGatewaysResponse(
  (json['VPNGateways'] as List<dynamic>?)
          ?.map((e) => AvailableVPNGateway.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ListAvailableVPNGatewaysResponseToJson(
  ListAvailableVPNGatewaysResponse instance,
) => <String, dynamic>{'VPNGateways': instance.vpnGateways};

NetworkStats _$NetworkStatsFromJson(Map<String, dynamic> json) => NetworkStats(
  (json['TotalIn'] as num).toInt(),
  (json['TotalOut'] as num).toInt(),
  (json['RateIn'] as num).toDouble(),
  (json['RateOut'] as num).toDouble(),
);

Map<String, dynamic> _$NetworkStatsToJson(NetworkStats instance) =>
    <String, dynamic>{
      'TotalIn': instance.totalIn,
      'TotalOut': instance.totalOut,
      'RateIn': instance.rateIn,
      'RateOut': instance.rateOut,
    };

FriendRequest _$FriendRequestFromJson(Map<String, dynamic> json) =>
    FriendRequest(
      json['PeerID'] as String,
      json['Alias'] as String,
      json['IpAddr'] as String,
      allowUsingAsExitNode: json['AllowUsingAsExitNode'] as bool? ?? false,
      token: json['Token'] as String? ?? '',
    );

Map<String, dynamic> _$FriendRequestToJson(FriendRequest instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Alias': instance.alias,
      'IpAddr': instance.ipAddr,
      'AllowUsingAsExitNode': instance.allowUsingAsExitNode,
      'Token': instance.token,
    };

ListAvailableProxiesResponse _$ListAvailableProxiesResponseFromJson(
  Map<String, dynamic> json,
) => ListAvailableProxiesResponse(
  (json['Proxies'] as List<dynamic>)
      .map((e) => AvailableProxy.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ListAvailableProxiesResponseToJson(
  ListAvailableProxiesResponse instance,
) => <String, dynamic>{'Proxies': instance.proxies};

AvailableProxy _$AvailableProxyFromJson(Map<String, dynamic> json) =>
    AvailableProxy(
      json['PeerID'] as String,
      json['PeerName'] as String,
      json['Connected'] as bool,
    );

Map<String, dynamic> _$AvailableProxyToJson(AvailableProxy instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'PeerName': instance.peerName,
      'Connected': instance.connected,
    };

FriendRequestReply _$FriendRequestReplyFromJson(Map<String, dynamic> json) =>
    FriendRequestReply(
      json['PeerID'] as String,
      json['Alias'] as String,
      json['Decline'] as bool,
      json['IpAddr'] as String,
      allowUsingAsExitNode: json['AllowUsingAsExitNode'] as bool? ?? false,
    );

Map<String, dynamic> _$FriendRequestReplyToJson(FriendRequestReply instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Alias': instance.alias,
      'Decline': instance.decline,
      'IpAddr': instance.ipAddr,
      'AllowUsingAsExitNode': instance.allowUsingAsExitNode,
    };

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) =>
    ApiError(json['error'] as String);

Map<String, dynamic> _$ApiErrorToJson(ApiError instance) => <String, dynamic>{
  'error': instance.error,
};

AuthRequest _$AuthRequestFromJson(Map<String, dynamic> json) => AuthRequest(
  json['PeerID'] as String,
  json['Name'] as String,
  json['SuggestedIP'] as String,
);

Map<String, dynamic> _$AuthRequestToJson(AuthRequest instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Name': instance.name,
      'SuggestedIP': instance.suggestedIP,
    };

PeerIDRequest _$PeerIDRequestFromJson(Map<String, dynamic> json) =>
    PeerIDRequest(json['PeerID'] as String);

Map<String, dynamic> _$PeerIDRequestToJson(PeerIDRequest instance) =>
    <String, dynamic>{'PeerID': instance.peerID};

KnownPeerConfig _$KnownPeerConfigFromJson(Map<String, dynamic> json) =>
    KnownPeerConfig(
      json['peerId'] as String,
      json['name'] as String,
      json['alias'] as String,
      json['ipAddr'] as String,
      json['domainName'] as String,
      json['weAllowUsingAsExitNode'] as bool,
      json['inviteID'] as String? ?? '',
    );

Map<String, dynamic> _$KnownPeerConfigToJson(KnownPeerConfig instance) =>
    <String, dynamic>{
      'peerId': instance.peerId,
      'name': instance.name,
      'alias': instance.alias,
      'ipAddr': instance.ipAddr,
      'domainName': instance.domainName,
      'weAllowUsingAsExitNode': instance.weAllowUsingAsExitNode,
      'inviteID': instance.inviteID,
    };

UpdateKnownPeerConfigRequest _$UpdateKnownPeerConfigRequestFromJson(
  Map<String, dynamic> json,
) => UpdateKnownPeerConfigRequest(
  json['PeerID'] as String,
  json['Alias'] as String,
  json['DomainName'] as String,
  json['IpAddr'] as String,
  json['AllowUsingAsExitNode'] as bool,
);

Map<String, dynamic> _$UpdateKnownPeerConfigRequestToJson(
  UpdateKnownPeerConfigRequest instance,
) => <String, dynamic>{
  'PeerID': instance.peerID,
  'Alias': instance.alias,
  'DomainName': instance.domainName,
  'IpAddr': instance.ipAddr,
  'AllowUsingAsExitNode': instance.allowUsingAsExitNode,
};

Invite _$InviteFromJson(Map<String, dynamic> json) => Invite(
  json['ID'] as String,
  json['Label'] as String,
  json['Link'] as String,
  json['Alias'] as String,
  json['AllowUsingAsExitNode'] as bool,
  (json['MaxUses'] as num).toInt(),
  (json['UsedCount'] as num).toInt(),
  DateTime.parse(json['ExpiresAt'] as String),
  DateTime.parse(json['CreatedAt'] as String),
  json['Revoked'] as bool,
  json['Status'] as String,
);

Map<String, dynamic> _$InviteToJson(Invite instance) => <String, dynamic>{
  'ID': instance.id,
  'Label': instance.label,
  'Link': instance.link,
  'Alias': instance.alias,
  'AllowUsingAsExitNode': instance.allowUsingAsExitNode,
  'MaxUses': instance.maxUses,
  'UsedCount': instance.usedCount,
  'ExpiresAt': instance.expiresAt.toIso8601String(),
  'CreatedAt': instance.createdAt.toIso8601String(),
  'Revoked': instance.revoked,
  'Status': instance.status,
};

CreateInviteRequest _$CreateInviteRequestFromJson(Map<String, dynamic> json) =>
    CreateInviteRequest(
      maxUses: (json['MaxUses'] as num?)?.toInt() ?? 1,
      expiresInSeconds: (json['ExpiresInSeconds'] as num?)?.toInt() ?? 0,
      alias: json['Alias'] as String? ?? '',
      allowUsingAsExitNode: json['AllowUsingAsExitNode'] as bool? ?? false,
      label: json['Label'] as String? ?? '',
    );

Map<String, dynamic> _$CreateInviteRequestToJson(
  CreateInviteRequest instance,
) => <String, dynamic>{
  'MaxUses': instance.maxUses,
  'ExpiresInSeconds': instance.expiresInSeconds,
  'Alias': instance.alias,
  'AllowUsingAsExitNode': instance.allowUsingAsExitNode,
  'Label': instance.label,
};

RevokeInviteRequest _$RevokeInviteRequestFromJson(Map<String, dynamic> json) =>
    RevokeInviteRequest(json['ID'] as String);

Map<String, dynamic> _$RevokeInviteRequestToJson(
  RevokeInviteRequest instance,
) => <String, dynamic>{'ID': instance.id};

BlockedPeer _$BlockedPeerFromJson(Map<String, dynamic> json) => BlockedPeer(
  json['peerId'] as String,
  json['displayName'] as String,
  DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$BlockedPeerToJson(BlockedPeer instance) =>
    <String, dynamic>{
      'peerId': instance.peerId,
      'displayName': instance.displayName,
      'createdAt': instance.createdAt.toIso8601String(),
    };
