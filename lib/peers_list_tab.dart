import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/peer_settings_screen.dart' show KnownPeerSettingsScreen;
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_error.dart';

/// Adapter for [PeersListView] that reads [knownPeersProvider] via Riverpod.
/// The pure presentation logic lives in [PeersListView].
class PeersListPage extends ConsumerWidget {
  final bool showCounter;

  const PeersListPage({super.key, this.showCounter = true});

  Future<void> _onPeerSettings(BuildContext context, KnownPeer peer) async {
    await Navigator.of(context).pushNamed(KnownPeerSettingsScreen.routeFor(peer.peerID));
  }

  Future<void> _onShowQR(BuildContext context, KnownPeer peer) async {
    await showQRDialog(context, peer.peerID, peer.displayName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knownPeers = ref.watch(knownPeersProvider).valueOrNull;
    final myPeerInfo = ref.watch(myPeerInfoProvider).valueOrNull;
    final proxyExitPeerID = myPeerInfo?.socks5.usingPeerID;

    return ValueListenableBuilder<bool>(
      valueListenable: isServerAvailable,
      builder: (context, isAvailable, child) {
        if (!isAvailable) {
          return Center(child: showDefaultServerConnectionError(context));
        }

        return PeersListView(
          peers: knownPeers,
          showCounter: showCounter,
          proxyExitPeerID: proxyExitPeerID,
          onPeerSettings: (peer) => _onPeerSettings(context, peer),
          onShowQR: (peer) => _onShowQR(context, peer),
        );
      },
    );
  }
}

/// Pure presentation widget for the peers list. Receives all data via
/// constructor params; never reads global services. Tests target this widget
/// directly with fixture data.
class PeersListView extends StatefulWidget {
  final List<KnownPeer>? peers;
  final bool showCounter;
  final String? proxyExitPeerID;
  final Future<void> Function(KnownPeer)? onPeerSettings;
  final Future<void> Function(KnownPeer)? onShowQR;

  const PeersListView({
    super.key,
    required this.peers,
    this.showCounter = true,
    this.proxyExitPeerID,
    this.onPeerSettings,
    this.onShowQR,
  });

  @override
  State<PeersListView> createState() => _PeersListViewState();
}

class _PeersListViewState extends State<PeersListView> {
  final Map<String?, bool> _expandedState = {};

  @override
  Widget build(BuildContext context) {
    final knownPeers = widget.peers;
    if (knownPeers == null || knownPeers.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lan_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            SizedBox(height: 12),
            Text("No known peers", style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 4),
            Text(
              "Use Add peer to connect to someone",
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final onlineCount = knownPeers.where((p) => p.connected && p.confirmed).length;
    final totalCount = knownPeers.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showCounter)
            Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: buildPeersOnlineIndicator(context, onlineCount, totalCount),
            ),
          ...knownPeers.map((item) {
            var isExpanded = _expandedState[item.peerID] ?? false;
            return _buildPeerCard(item, isExpanded);
          }),
        ],
      ),
    );
  }

  String _peerStatusText(KnownPeer peer) {
    if (peer.declined) return "Rejected";
    if (!peer.confirmed) return "Not accepted";
    if (!peer.connected) return "Disconnected";
    return "Connected";
  }

  Color _peerStatusColor(BuildContext context, KnownPeer peer) {
    if (peer.declined) return errorColor;
    if (!peer.confirmed) return unknownStatusColor(context);
    if (!peer.connected) return errorColor;
    return successColor;
  }

  Widget _buildPeerCard(KnownPeer peer, bool isExpanded) {
    final colorScheme = Theme.of(context).colorScheme;
    var subtitle = peer.ipAddr;
    if (peer.domainName.isNotEmpty) {
      subtitle = "${peer.domainName}.awl";
    }
    // "last seen" as a separate line for disconnected confirmed peers
    String? lastSeenText;
    if (!peer.connected && peer.confirmed && peer.lastSeen.isAfter(zeroGoTime)) {
      lastSeenText = "last seen ${formatDurationRough(peer.lastSeen.difference(DateTime.now()))} ago";
    }
    final isProxyExit =
        widget.proxyExitPeerID != null &&
        widget.proxyExitPeerID!.isNotEmpty &&
        widget.proxyExitPeerID == peer.peerID;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: _peerStatusColor(context, peer), width: 4)),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _expandedState[peer.peerID] = !isExpanded;
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  peer.displayName,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isProxyExit) ...[SizedBox(width: 12), _ExitBadge()],
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(subtitle, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                          if (lastSeenText != null) ...[
                            SizedBox(height: 1),
                            Text(
                              lastSeenText,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    StatusPill(
                      text: _peerStatusText(peer),
                      color: _peerStatusColor(context, peer),
                      withDot: peer.connected && peer.confirmed,
                    ),
                    SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _buildExpansionPanelBody(peer),
                    )
                  : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionPanelBody(KnownPeer item) {
    final isWide = MediaQuery.of(context).size.width > 850;

    // Collect detail entries as (label, value) pairs
    final details = <MapEntry<String, String>>[];

    if (!item.connected && item.confirmed) {
      details.add(MapEntry("LAST SEEN", "${formatDuration(item.lastSeen.difference(DateTime.now()))} ago"));
    }
    details.add(MapEntry("VPN ADDRESS", "${item.domainName}.awl · ${item.ipAddr}"));
    // Connections handled separately for widget
    details.add(MapEntry("USE AS EXIT", item.allowedUsingAsExitNode ? "Allowed" : "Denied"));
    details.add(MapEntry("OFFER AS EXIT", item.weAllowUsingAsExitNode ? "Allowed" : "Denied"));
    if (item.networkStats.totalIn != 0) {
      details.add(MapEntry("DOWNLOAD", item.networkStats.inAsString()));
    }
    if (item.networkStats.totalOut != 0) {
      details.add(MapEntry("UPLOAD", item.networkStats.outAsString()));
    }
    if (item.ping.inMicroseconds != 0) {
      details.add(MapEntry("PING", formatLatencyDuration(item.ping)));
    }
    if (item.version.isNotEmpty) {
      details.add(MapEntry("VERSION", item.version));
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Connection widget (needs special handling — not a simple string)
    Widget? connectionWidget;
    if (item.connections.isNotEmpty) {
      connectionWidget = _buildGridCell("CONNECTION", _buildConnectionsWidget(item.connections), colorScheme);
    }

    Widget detailsWidget;
    if (isWide) {
      // 2-column grid on desktop
      final cells = <Widget>[];
      for (var entry in details) {
        final isExitRow = entry.key == "USE AS EXIT" || entry.key == "OFFER AS EXIT";
        final color = isExitRow
            ? (entry.value == "Allowed" ? successColor : colorScheme.onSurfaceVariant)
            : null;
        cells.add(
          _buildGridCell(
            entry.key,
            SelectableText(
              entry.value,
              style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500),
            ),
            colorScheme,
          ),
        );
      }
      if (connectionWidget != null) {
        // Insert connection after VPN ADDRESS (index 1, or 2 if last seen is present)
        final insertIdx = (!item.connected && item.confirmed) ? 2 : 1;
        cells.insert(insertIdx, connectionWidget);
      }

      detailsWidget = LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          if (availableWidth < 300) {
            // Fall back to single column on very narrow panels
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: cells);
          }
          final cellWidth = (availableWidth - 16) / 2; // 2 columns with 16px gap
          return Wrap(
            spacing: 16,
            runSpacing: 12,
            children: cells.map((c) => SizedBox(width: cellWidth, child: c)).toList(),
          );
        },
      );
    } else {
      // Single column rows on mobile: label left, value right
      final rows = <Widget>[];
      for (var entry in details) {
        final isExitRow = entry.key == "USE AS EXIT" || entry.key == "OFFER AS EXIT";
        final color = isExitRow
            ? (entry.value == "Allowed" ? successColor : colorScheme.onSurfaceVariant)
            : null;
        rows.add(
          _buildMobileRow(
            entry.key,
            SelectableText(
              entry.value,
              style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        );
      }
      if (item.connections.isNotEmpty) {
        final insertIdx = (!item.connected && item.confirmed) ? 2 : 1;
        rows.insert(insertIdx, _buildMobileRow("CONNECTION", _buildConnectionsWidget(item.connections)));
      }
      detailsWidget = Column(children: rows);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: colorScheme.outlineVariant),
        SizedBox(height: 12),
        detailsWidget,
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: Icon(Icons.qr_code),
              label: Text("Show ID"),
              onPressed: () => widget.onShowQR?.call(item),
            ),
            SizedBox(width: 8),
            FilledButton.tonalIcon(
              icon: Icon(Icons.settings),
              label: Text("Settings"),
              onPressed: () => widget.onPeerSettings?.call(item),
            ),
          ],
        ),
      ],
    );
  }

  static const _detailIcons = <String, IconData>{
    'LAST SEEN': Icons.schedule,
    'VPN ADDRESS': Icons.language,
    'CONNECTION': Icons.sync_alt,
    'USE AS EXIT': Icons.logout_rounded,
    'OFFER AS EXIT': Icons.login_rounded,
    'PING': Icons.timer_outlined,
    'DOWNLOAD': Icons.cloud_download_outlined,
    'UPLOAD': Icons.cloud_upload_outlined,
    'VERSION': Icons.info_outlined,
  };

  static const _detailLabels = <String, String>{
    'LAST SEEN': 'Last seen',
    'VPN ADDRESS': 'VPN address',
    'CONNECTION': 'Connection',
    'USE AS EXIT': 'Use as exit',
    'OFFER AS EXIT': 'Offer as exit',
    'PING': 'Ping',
    'DOWNLOAD': 'Download',
    'UPLOAD': 'Upload',
    'VERSION': 'Version',
  };

  Widget _buildGridCell(String label, Widget value, ColorScheme colorScheme) {
    final icon = _detailIcons[label];
    final displayLabel = _detailLabels[label] ?? label;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurface.withValues(alpha: 0.72),
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
              SizedBox(width: 4),
            ],
            Text(displayLabel, style: labelStyle),
          ],
        ),
        SizedBox(height: 4),
        value,
      ],
    );
  }

  Widget _buildMobileRow(String label, Widget value) {
    final displayLabel = _detailLabels[label] ?? label;
    final icon = _detailIcons[label];
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
                SizedBox(width: 6),
              ],
              Text(
                displayLabel,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.72)),
              ),
            ],
          ),
          SizedBox(width: 16),
          Flexible(fit: FlexFit.loose, child: value),
        ],
      ),
    );
  }

  Widget _buildConnectionsWidget(List<ConnectionInfo> connections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: connections.map((connection) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                connection.toString(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 5),
              Tooltip(
                // TODO: display info about relay if throughRelay (name, ping?, country/location?)
                message: connection.multiaddr,
                child: const Icon(Icons.info_outline, size: 16),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

Widget buildPeersOnlineIndicator(BuildContext context, int online, int total) {
  if (total == 0) return const SizedBox.shrink();
  final colorScheme = Theme.of(context).colorScheme;
  final dotColor = online > 0 ? successColor : colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      ),
      SizedBox(width: 8),
      Text('$online/$total online', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
    ],
  );
}

class _ExitBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'SOCKS5 proxy traffic exits through this peer',
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.exit_to_app_rounded, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Exit node',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatLatencyDuration(Duration duration) {
  if (duration.inMicroseconds == 0) {
    return "–";
  }

  final ms = duration.inMilliseconds;
  return "$ms ms";
}
