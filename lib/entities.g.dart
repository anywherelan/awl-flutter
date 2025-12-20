// GENERATED CODE - DO NOT MODIFY BY HAND

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
  _durationFromNanoseconds((json['Ping'] as num).toInt()),
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
    };

SOCKS5Info _$SOCKS5InfoFromJson(Map<String, dynamic> json) => SOCKS5Info(
  json['ListenAddress'] as String,
  json['ProxyingEnabled'] as bool,
  json['ListenerEnabled'] as bool,
  json['UsingPeerID'] as String,
  json['UsingPeerName'] as String,
);

Map<String, dynamic> _$SOCKS5InfoToJson(SOCKS5Info instance) =>
    <String, dynamic>{
      'ListenAddress': instance.listenAddress,
      'ProxyingEnabled': instance.proxyingEnabled,
      'ListenerEnabled': instance.listenerEnabled,
      'UsingPeerID': instance.usingPeerID,
      'UsingPeerName': instance.usingPeerName,
    };

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
    FriendRequest(json['PeerID'] as String, json['Alias'] as String);

Map<String, dynamic> _$FriendRequestToJson(FriendRequest instance) =>
    <String, dynamic>{'PeerID': instance.peerID, 'Alias': instance.alias};

ListAvailableProxiesResponse _$ListAvailableProxiesResponseFromJson(Map<String, dynamic> json,) =>
    ListAvailableProxiesResponse(
      (json['Proxies'] as List<dynamic>)
          .map((e) => AvailableProxy.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ListAvailableProxiesResponseToJson(ListAvailableProxiesResponse instance,) =>
    <String, dynamic>{'Proxies': instance.proxies};

AvailableProxy _$AvailableProxyFromJson(Map<String, dynamic> json) =>
    AvailableProxy(json['PeerID'] as String, json['PeerName'] as String);

Map<String, dynamic> _$AvailableProxyToJson(AvailableProxy instance) =>
    <String, dynamic>{'PeerID': instance.peerID, 'PeerName': instance.peerName};

FriendRequestReply _$FriendRequestReplyFromJson(Map<String, dynamic> json) =>
    FriendRequestReply(
      json['PeerID'] as String,
      json['Alias'] as String,
      json['Decline'] as bool,
    );

Map<String, dynamic> _$FriendRequestReplyToJson(FriendRequestReply instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Alias': instance.alias,
      'Decline': instance.decline,
    };

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) =>
    ApiError(json['error'] as String);

Map<String, dynamic> _$ApiErrorToJson(ApiError instance) => <String, dynamic>{
  'error': instance.error,
};

AuthRequest _$AuthRequestFromJson(Map<String, dynamic> json) =>
    AuthRequest(json['PeerID'] as String, json['Name'] as String);

Map<String, dynamic> _$AuthRequestToJson(AuthRequest instance) =>
    <String, dynamic>{'PeerID': instance.peerID, 'Name': instance.name};

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
    );

Map<String, dynamic> _$KnownPeerConfigToJson(KnownPeerConfig instance) =>
    <String, dynamic>{
      'peerId': instance.peerId,
      'name': instance.name,
      'alias': instance.alias,
      'ipAddr': instance.ipAddr,
      'domainName': instance.domainName,
      'weAllowUsingAsExitNode': instance.weAllowUsingAsExitNode,
    };

UpdateKnownPeerConfigRequest _$UpdateKnownPeerConfigRequestFromJson(Map<String, dynamic> json,) =>
    UpdateKnownPeerConfigRequest(
      json['PeerID'] as String,
      json['Alias'] as String,
      json['DomainName'] as String,
      json['IpAddr'] as String,
      json['AllowUsingAsExitNode'] as bool,
    );

Map<String, dynamic> _$UpdateKnownPeerConfigRequestToJson(UpdateKnownPeerConfigRequest instance,) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Alias': instance.alias,
      'DomainName': instance.domainName,
      'IpAddr': instance.ipAddr,
      'AllowUsingAsExitNode': instance.allowUsingAsExitNode,
    };

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
