import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/peer_settings_screen.dart' show KnownPeerSettingsScreen;
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/qr_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_error.dart';

/// Min width of the expanded peer-details panel at which it switches from
/// single-column rows (label left, value right) to a 2-column grid. Measured
/// against the panel's *actual* width via [LayoutBuilder] — not the global
/// screen width — so it stays correct inside the side-by-side peers column.
const double _kPeerDetailsTwoColumnMinWidth = 430;

/// Adapter for [PeersListView] that reads [knownPeersProvider] via Riverpod.
/// The pure presentation logic lives in [PeersListView].
class PeersListPage extends ConsumerWidget {
  final bool showCounter;

  const PeersListPage({super.key, this.showCounter = true});

  Future<void> _onPeerSettings(BuildContext context, KnownPeer peer) async {
    await Navigator.of(context).pushNamed(KnownPeerSettingsScreen.routeFor(peer.peerID));
  }

  Future<void> _onShowQR(BuildContext context, KnownPeer peer) async {
    await showPeerQRDialog(context, peer.peerID, peer.displayName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knownPeers = ref.watch(knownPeersProvider).valueOrNull;
    final myPeerInfo = ref.watch(myPeerInfoProvider).valueOrNull;
    final proxyExitPeerID = myPeerInfo?.socks5.usingPeerID;
    final gatewayExitPeerID = (myPeerInfo?.vpnGateway.clientEnabled ?? false)
        ? myPeerInfo?.vpnGateway.gatewayPeerID
        : null;

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
          gatewayExitPeerID: gatewayExitPeerID,
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
  final String? gatewayExitPeerID;
  final Future<void> Function(KnownPeer)? onPeerSettings;
  final Future<void> Function(KnownPeer)? onShowQR;

  const PeersListView({
    super.key,
    required this.peers,
    this.showCounter = true,
    this.proxyExitPeerID,
    this.gatewayExitPeerID,
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
    final isGatewayExit =
        widget.gatewayExitPeerID != null &&
        widget.gatewayExitPeerID!.isNotEmpty &&
        widget.gatewayExitPeerID == peer.peerID;
    final badges = <_PeerBadgeSpec>[if (isProxyExit) _kProxyExitBadge, if (isGatewayExit) _kVpnGatewayBadge];

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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final badgeLayout = _resolveBadgeLayout(
                            context,
                            constraints.maxWidth,
                            peer.displayName,
                            badges,
                          );
                          return Column(
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
                                  if (badgeLayout != _BadgeLayout.ownRow)
                                    for (final (i, badge) in badges.indexed) ...[
                                      SizedBox(width: i == 0 ? _kBadgeLeadingGap : _kBadgeInterGap),
                                      _PeerBadge(badge, short: badgeLayout == _BadgeLayout.inlineShort),
                                    ],
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                              ),
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
                              if (badgeLayout == _BadgeLayout.ownRow) ...[
                                SizedBox(height: 6),
                                Wrap(
                                  spacing: _kBadgeInterGap,
                                  runSpacing: 4,
                                  children: [for (final badge in badges) _PeerBadge(badge)],
                                ),
                              ],
                            ],
                          );
                        },
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
    // Collect detail entries as (label, value) pairs
    final details = <MapEntry<String, String>>[];

    if (!item.connected && item.confirmed) {
      details.add(MapEntry("LAST SEEN", "${formatDuration(item.lastSeen.difference(DateTime.now()))} ago"));
    }
    details.add(MapEntry("VPN ADDRESS", "${item.domainName}.awl · ${item.ipAddr}"));
    // Connections handled separately (a widget, not a simple string).
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

    // CONNECTION slots in after VPN ADDRESS (index 1, or 2 if "last seen" leads).
    final connectionInsertIdx = (!item.connected && item.confirmed) ? 2 : 1;

    Color? valueColor(String label, String value) {
      final isExitRow = label == "USE AS EXIT" || label == "OFFER AS EXIT";
      if (!isExitRow) return null;
      return value == "Allowed" ? successColor : colorScheme.onSurfaceVariant;
    }

    Widget valueText(MapEntry<String, String> entry) => SelectableText(
      entry.value,
      style: TextStyle(fontSize: 14, color: valueColor(entry.key, entry.value), fontWeight: FontWeight.w500),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: colorScheme.outlineVariant),
        SizedBox(height: 12),
        // Decide 1- vs 2-column details by the panel's actual width, not the
        // global screen width, so it stays correct inside the side-by-side
        // peers column (and any future width cap).
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= _kPeerDetailsTwoColumnMinWidth;
            if (twoColumns) {
              final cells = <Widget>[
                for (final entry in details) _buildGridCell(entry.key, valueText(entry), colorScheme),
              ];
              if (item.connections.isNotEmpty) {
                cells.insert(
                  connectionInsertIdx,
                  _buildGridCell("CONNECTION", _buildConnectionsWidget(item.connections), colorScheme),
                );
              }
              final cellWidth = (constraints.maxWidth - 16) / 2; // 2 columns with 16px gap
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: cells.map((c) => SizedBox(width: cellWidth, child: c)).toList(),
              );
            }

            // Single column: label left, value right.
            final rows = <Widget>[for (final entry in details) _buildMobileRow(entry.key, valueText(entry))];
            if (item.connections.isNotEmpty) {
              rows.insert(
                connectionInsertIdx,
                _buildMobileRow("CONNECTION", _buildConnectionsWidget(item.connections)),
              );
            }
            return Column(children: rows);
          },
        ),
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
              Flexible(
                child: SelectableText(
                  connection.toString(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
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

class _PeerBadgeSpec {
  final IconData icon;
  final String fullLabel;
  final String shortLabel;
  final String tooltip;

  const _PeerBadgeSpec({
    required this.icon,
    required this.fullLabel,
    required this.shortLabel,
    required this.tooltip,
  });
}

const _kProxyExitBadge = _PeerBadgeSpec(
  icon: Icons.exit_to_app_rounded,
  fullLabel: 'SOCKS5 exit',
  shortLabel: 'SOCKS5',
  tooltip: 'SOCKS5 proxy traffic exits through this device',
);

const _kVpnGatewayBadge = _PeerBadgeSpec(
  icon: Icons.vpn_lock_outlined,
  fullLabel: 'VPN gateway',
  shortLabel: 'VPN',
  tooltip: 'All internet traffic exits through this device (VPN gateway)',
);

/// How the exit/gateway badges are placed relative to the peer name.
/// Resolved by [_resolveBadgeLayout] from the header's *actual* width
/// (same LayoutBuilder convention as [_kPeerDetailsTwoColumnMinWidth]).
enum _BadgeLayout { inlineFull, inlineShort, ownRow }

/// The peer name never ellipsizes below this many characters; badges shrink
/// to short labels and then move to their own row instead.
const int _kMinVisibleNameChars = 12;

/// Fixed (non-text) width of a [_PeerBadge]: left padding + icon + icon-text
/// gap + right padding. Must match [_PeerBadge.build].
const double _kBadgeChromeWidth = 8 + 14 + 6 + 10;

const double _kBadgeLeadingGap = 12; // between peer name and first badge
const double _kBadgeInterGap = 8; // between adjacent badges

/// Color is applied in [_PeerBadge.build]; kept color-less here so
/// [_resolveBadgeLayout] can measure with the exact same style.
const TextStyle _kBadgeLabelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.0);

_BadgeLayout _resolveBadgeLayout(
  BuildContext context,
  double maxWidth,
  String peerName,
  List<_PeerBadgeSpec> badges,
) {
  if (badges.isEmpty) return _BadgeLayout.inlineFull;

  final textScaler = MediaQuery.textScalerOf(context);

  // Merge with DefaultTextStyle the same way the rendered Text does —
  // otherwise inherited properties (e.g. bodyMedium's letterSpacing)
  // make the real text wider than measured.
  final baseStyle = DefaultTextStyle.of(context).style;

  double textWidth(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: baseStyle.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  // The ellipsis renders *inside* the name's width, so reserve room for it
  // too — otherwise the visible-characters guarantee comes up short.
  final minName = peerName.length <= _kMinVisibleNameChars
      ? peerName
      : '${peerName.substring(0, _kMinVisibleNameChars)}…';
  final minNameWidth = textWidth(minName, Theme.of(context).textTheme.titleMedium);

  double badgesWidth(bool short) {
    var width = _kBadgeLeadingGap + _kBadgeInterGap * (badges.length - 1);
    for (final badge in badges) {
      width += _kBadgeChromeWidth + textWidth(short ? badge.shortLabel : badge.fullLabel, _kBadgeLabelStyle);
    }
    return width;
  }

  if (minNameWidth + badgesWidth(false) <= maxWidth) return _BadgeLayout.inlineFull;
  if (minNameWidth + badgesWidth(true) <= maxWidth) return _BadgeLayout.inlineShort;
  return _BadgeLayout.ownRow;
}

class _PeerBadge extends StatelessWidget {
  final _PeerBadgeSpec spec;
  final bool short;

  const _PeerBadge(this.spec, {this.short = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: spec.tooltip,
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
            Icon(spec.icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              short ? spec.shortLabel : spec.fullLabel,
              style: _kBadgeLabelStyle.copyWith(color: colorScheme.onSurfaceVariant),
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
