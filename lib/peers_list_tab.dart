import 'package:anywherelan/common.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/peer_settings_screen.dart' show KnownPeerSettingsScreen;
import 'package:flutter/material.dart';

import 'connection_error.dart';

/// Adapter for [PeersListView] that wires the widget to the global
/// [knownPeersDataService] singleton. The pure presentation logic lives in
/// [PeersListView] so it can be tested without that global. This adapter will
/// go away when ServerDataService is replaced.
class PeersListPage extends StatefulWidget {
  PeersListPage({Key? key}) : super(key: key);

  @override
  _PeersListPageState createState() => _PeersListPageState();
}

class _PeersListPageState extends State<PeersListPage> {
  List<KnownPeer>? _knownPeers;

  void _onNewKnownPeers(List<KnownPeer>? newPeers) async {
    if (!this.mounted) {
      return;
    }
    setState(() {
      _knownPeers = newPeers;
    });
  }

  @override
  void initState() {
    super.initState();

    _knownPeers = knownPeersDataService.getData();
    knownPeersDataService.subscribe(_onNewKnownPeers);
  }

  @override
  void dispose() {
    super.dispose();
    knownPeersDataService.unsubscribe(_onNewKnownPeers);
  }

  Future<void> _onPeerSettings(KnownPeer peer) async {
    knownPeersDataService.unsubscribe(_onNewKnownPeers);
    await Navigator.of(context).pushNamed(KnownPeerSettingsScreen.routeFor(peer.peerID));
    knownPeersDataService.subscribe(_onNewKnownPeers);
  }

  Future<void> _onShowQR(KnownPeer peer) async {
    knownPeersDataService.unsubscribe(_onNewKnownPeers);
    await showQRDialog(context, peer.peerID, peer.displayName);
    knownPeersDataService.subscribe(_onNewKnownPeers);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isServerAvailable,
      builder: (context, isAvailable, child) {
        if (!isAvailable) {
          return Center(child: showDefaultServerConnectionError(context));
        }

        return PeersListView(peers: _knownPeers, onPeerSettings: _onPeerSettings, onShowQR: _onShowQR);
      },
    );
  }
}

/// Pure presentation widget for the peers list. Receives all data via
/// constructor params; never reads global services. Tests target this widget
/// directly with fixture data.
class PeersListView extends StatefulWidget {
  final List<KnownPeer>? peers;
  final Future<void> Function(KnownPeer)? onPeerSettings;
  final Future<void> Function(KnownPeer)? onShowQR;

  const PeersListView({Key? key, required this.peers, this.onPeerSettings, this.onShowQR}) : super(key: key);

  @override
  State<PeersListView> createState() => _PeersListViewState();
}

class _PeersListViewState extends State<PeersListView> {
  final Map<String?, bool> _expandedState = Map();

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

    // Peer count summary
    final onlineCount = knownPeers.where((p) => p.connected && p.confirmed).length;
    final totalCount = knownPeers.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$totalCount peers · $onlineCount online',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
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
      subtitle = peer.domainName + ".awl";
    }
    // "last seen" as a separate line for disconnected confirmed peers
    String? lastSeenText;
    if (!peer.connected && peer.confirmed && peer.lastSeen.isAfter(zeroGoTime)) {
      lastSeenText = "last seen ${formatDurationRough(peer.lastSeen.difference(DateTime.now()))} ago";
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(peer.displayName, style: Theme.of(context).textTheme.titleMedium),
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
                    Text(
                      _peerStatusText(peer),
                      style: TextStyle(fontSize: 13, color: _peerStatusColor(context, peer)),
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
    details.add(MapEntry("VPN ADDRESS", "${item.domainName}.awl┃${item.ipAddr}"));
    // Connections handled separately for widget
    details.add(
      MapEntry("EXIT NODE", formatExitNodeStatus(item.weAllowUsingAsExitNode, item.allowedUsingAsExitNode)),
    );
    if (item.ping.inMicroseconds != 0) {
      details.add(MapEntry("PING", formatLatencyDuration(item.ping)));
    }
    if (item.networkStats.totalIn != 0) {
      details.add(MapEntry("DOWNLOAD", item.networkStats.inAsString()));
    }
    if (item.networkStats.totalOut != 0) {
      details.add(MapEntry("UPLOAD", item.networkStats.outAsString()));
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
        final color = entry.key == "EXIT NODE"
            ? exitNodeStatusColor(context, item.weAllowUsingAsExitNode, item.allowedUsingAsExitNode)
            : null;
        cells.add(
          _buildGridCell(
            entry.key,
            SelectableText(entry.value, style: TextStyle(fontSize: 14, color: color)),
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
        final color = entry.key == "EXIT NODE"
            ? exitNodeStatusColor(context, item.weAllowUsingAsExitNode, item.allowedUsingAsExitNode)
            : null;
        rows.add(
          _buildMobileRow(
            entry.key,
            SelectableText(entry.value, style: TextStyle(fontSize: 14, color: color)),
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
            FilledButton.tonalIcon(
              icon: Icon(Icons.settings),
              label: Text("Settings"),
              onPressed: () => widget.onPeerSettings?.call(item),
            ),
            SizedBox(width: 12),
            OutlinedButton.icon(
              icon: Icon(Icons.qr_code),
              label: Text("Show ID"),
              onPressed: () => widget.onShowQR?.call(item),
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
    'EXIT NODE': Icons.vpn_key_outlined,
    'PING': Icons.timer_outlined,
    'DOWNLOAD': Icons.cloud_download_outlined,
    'UPLOAD': Icons.cloud_upload_outlined,
    'VERSION': Icons.info_outlined,
  };

  static const _detailLabels = <String, String>{
    'LAST SEEN': 'Last seen',
    'VPN ADDRESS': 'VPN address',
    'CONNECTION': 'Connection',
    'EXIT NODE': 'Exit node',
    'PING': 'Ping',
    'DOWNLOAD': 'Download',
    'UPLOAD': 'Upload',
    'VERSION': 'Version',
  };

  Widget _buildGridCell(String label, Widget value, ColorScheme colorScheme) {
    final icon = _detailIcons[label];
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
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
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
              Text(displayLabel, style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
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
              SelectableText(connection.toString()),
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

String formatLatencyDuration(Duration duration) {
  if (duration.inMicroseconds == 0) {
    return "–";
  }

  final ms = duration.inMilliseconds;
  return "$ms ms";
}
