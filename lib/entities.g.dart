// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KnownPeer _$KnownPeerFromJson(Map<String, dynamic> json) {
  return KnownPeer(
    json['PeerID'] as String,
    json['Name'] as String,
    json['Version'] as String,
    json['IpAddr'] as String,
    json['Connected'] as bool,
    json['Confirmed'] as bool,
    DateTime.parse(json['LastSeen'] as String),
    (json['Addresses'] as List<dynamic>).map((e) => e as String).toList(),
    NetworkStats.fromJson(json['NetworkStats'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$KnownPeerToJson(KnownPeer instance) => <String, dynamic>{
      'PeerID': instance.peerID,
      'Name': instance.name,
      'Version': instance.version,
      'IpAddr': instance.ipAddr,
      'Connected': instance.connected,
      'Confirmed': instance.confirmed,
      'LastSeen': instance.lastSeen.toIso8601String(),
      'Addresses': instance.addresses,
      'NetworkStats': instance.networkStats,
    };

MyPeerInfo _$MyPeerInfoFromJson(Map<String, dynamic> json) {
  return MyPeerInfo(
    json['PeerID'] as String,
    json['Name'] as String,
    MyPeerInfo._durationFromNanoseconds(json['Uptime'] as int),
    json['ServerVersion'] as String,
    NetworkStats.fromJson(json['NetworkStats'] as Map<String, dynamic>),
    json['TotalBootstrapPeers'] as int,
    json['ConnectedBootstrapPeers'] as int,
  );
}

Map<String, dynamic> _$MyPeerInfoToJson(MyPeerInfo instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Name': instance.name,
      'Uptime': MyPeerInfo._durationToNanoseconds(instance.uptime),
      'ServerVersion': instance.serverVersion,
      'NetworkStats': instance.networkStats,
      'TotalBootstrapPeers': instance.totalBootstrapPeers,
      'ConnectedBootstrapPeers': instance.connectedBootstrapPeers,
    };

NetworkStats _$NetworkStatsFromJson(Map<String, dynamic> json) {
  return NetworkStats(
    json['TotalIn'] as int,
    json['TotalOut'] as int,
    (json['RateIn'] as num).toDouble(),
    (json['RateOut'] as num).toDouble(),
  );
}

Map<String, dynamic> _$NetworkStatsToJson(NetworkStats instance) =>
    <String, dynamic>{
      'TotalIn': instance.totalIn,
      'TotalOut': instance.totalOut,
      'RateIn': instance.rateIn,
      'RateOut': instance.rateOut,
    };

FriendRequest _$FriendRequestFromJson(Map<String, dynamic> json) {
  return FriendRequest(
    json['PeerID'] as String,
    json['Alias'] as String,
  );
}

Map<String, dynamic> _$FriendRequestToJson(FriendRequest instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Alias': instance.alias,
    };

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) {
  return ApiError(
    json['error'] as String,
  );
}

Map<String, dynamic> _$ApiErrorToJson(ApiError instance) => <String, dynamic>{
      'error': instance.error,
    };

AuthRequest _$AuthRequestFromJson(Map<String, dynamic> json) {
  return AuthRequest(
    json['PeerID'] as String,
    json['Name'] as String,
  );
}

Map<String, dynamic> _$AuthRequestToJson(AuthRequest instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Name': instance.name,
    };

PeerIDRequest _$PeerIDRequestFromJson(Map<String, dynamic> json) {
  return PeerIDRequest(
    json['PeerID'] as String,
  );
}

Map<String, dynamic> _$PeerIDRequestToJson(PeerIDRequest instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
    };

KnownPeerConfig _$KnownPeerConfigFromJson(Map<String, dynamic> json) {
  return KnownPeerConfig(
    json['peerId'] as String,
    json['name'] as String,
    json['alias'] as String,
    json['ipAddr'] as String,
  );
}

Map<String, dynamic> _$KnownPeerConfigToJson(KnownPeerConfig instance) =>
    <String, dynamic>{
      'peerId': instance.peerId,
      'name': instance.name,
      'alias': instance.alias,
      'ipAddr': instance.ipAddr,
    };

UpdateKnownPeerConfigRequest _$UpdateKnownPeerConfigRequestFromJson(
    Map<String, dynamic> json) {
  return UpdateKnownPeerConfigRequest(
    json['PeerID'] as String,
    json['Alias'] as String,
  );
}

Map<String, dynamic> _$UpdateKnownPeerConfigRequestToJson(
        UpdateKnownPeerConfigRequest instance) =>
    <String, dynamic>{
      'PeerID': instance.peerID,
      'Alias': instance.alias,
    };
