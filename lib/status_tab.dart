import 'dart:async';

import 'package:anywherelan/common.dart';
import 'package:anywherelan/connection_error.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adapter for [StatusPageView] that reads [myPeerInfoProvider] and
/// [availableProxiesProvider] via Riverpod. The pure presentation logic
/// lives in [StatusPageView].
class StatusPage extends ConsumerStatefulWidget {
  final bool showDeviceHeader;

  const StatusPage({super.key, this.showDeviceHeader = true});

  @override
  ConsumerState<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends ConsumerState<StatusPage> {
  bool _openedSetupDialog = false;

  Future<String> _onUpdateProxy(String usingPeerID) async {
    final response = await ref.read(apiProvider).updateProxySettings(usingPeerID);
    if (response == "") {
      await Future.wait([
        ref.read(myPeerInfoProvider.notifier).refresh(),
        ref.read(availableProxiesProvider.notifier).refresh(),
      ]);
    }
    return response;
  }

  Future<String> _onUpdateGateway(String gatewayPeerID) async {
    final api = ref.read(apiProvider);
    final response = gatewayPeerID.isEmpty
        ? await api.disableVPNGatewayClient()
        : await api.enableVPNGatewayClient(gatewayPeerID);
    if (response == "") {
      // The backend has persisted the new gateway state, but on Android it does
      // not change routing by itself: the host must re-establish the VPN with
      // the new routes and hot-swap the tun fd into the backend. This is a
      // best-effort step — on failure the persisted state is ahead of actual
      // routing, so we surface it rather than silently rolling back.
      final reconfigureErr = await reconfigureVpn();
      if (reconfigureErr.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('VPN routing not applied: $reconfigureErr. Restart the VPN to apply.'),
          ),
        );
      }
      await Future.wait([
        ref.read(myPeerInfoProvider.notifier).refresh(),
        ref.read(availableVPNGatewaysProvider.notifier).refresh(),
      ]);
    }
    return response;
  }

  Future<void> _onShowQR(MyPeerInfo peerInfo) async {
    await showQRDialog(context, peerInfo.peerID, peerInfo.name);
  }

  Future<void> _onShowSettings(MyPeerInfo? peerInfo, {bool firstSetup = false}) async {
    await showSettingsDialog(context, peerInfo, firstSetup);
  }

  @override
  Widget build(BuildContext context) {
    final peerInfo = ref.watch(myPeerInfoProvider).valueOrNull;
    final proxiesData = ref.watch(availableProxiesProvider).valueOrNull;
    final gatewaysData = ref.watch(availableVPNGatewaysProvider).valueOrNull;

    return ValueListenableBuilder<bool>(
      valueListenable: isServerAvailable,
      builder: (context, isAvailable, child) {
        if (!isAvailable) {
          return Center(child: showDefaultServerConnectionError(context));
        }

        // First-run auto-popup: open settings dialog when the server is up
        // but the user hasn't picked a name yet.
        if (peerInfo != null) {
          final serverIsUp = peerInfo.uptime.inMicroseconds > 0;
          if (!_openedSetupDialog && serverIsUp && peerInfo.name.isEmpty) {
            _openedSetupDialog = true;
            Future.delayed(Duration(seconds: 2), () => _onShowSettings(peerInfo, firstSetup: true));
          }
        }

        return StatusPageView(
          peerInfo: peerInfo,
          proxiesData: proxiesData,
          gatewaysData: gatewaysData,
          showDeviceHeader: widget.showDeviceHeader,
          onUpdateProxy: _onUpdateProxy,
          onUpdateGateway: _onUpdateGateway,
          onShowQR: peerInfo != null ? () => _onShowQR(peerInfo) : null,
          onShowSettings: () => _onShowSettings(peerInfo),
        );
      },
    );
  }
}

/// Pure presentation widget for the status screen. Receives all data via
/// constructor params; never reads global services. Tests target this widget
/// directly with fixture data.
class StatusPageView extends StatefulWidget {
  final MyPeerInfo? peerInfo;
  final ListAvailableProxiesResponse? proxiesData;
  final ListAvailableVPNGatewaysResponse? gatewaysData;
  final bool showDeviceHeader;
  final Future<String> Function(String usingPeerID)? onUpdateProxy;
  final Future<String> Function(String gatewayPeerID)? onUpdateGateway;
  final Future<void> Function()? onShowQR;
  final Future<void> Function()? onShowSettings;

  const StatusPageView({
    super.key,
    required this.peerInfo,
    this.proxiesData,
    this.gatewaysData,
    this.showDeviceHeader = true,
    this.onUpdateProxy,
    this.onUpdateGateway,
    this.onShowQR,
    this.onShowSettings,
  });

  @override
  State<StatusPageView> createState() => _StatusPageViewState();
}

class _StatusPageViewState extends State<StatusPageView> {
  MyPeerInfo get _peerInfo => widget.peerInfo!;

  @override
  Widget build(BuildContext context) {
    if (widget.peerInfo == null) {
      return Container();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showDeviceHeader) ...[
            SizedBox(height: 4),
            buildDeviceHeader(
              context,
              _peerInfo,
              onShowQR: widget.onShowQR,
              onShowSettings: widget.onShowSettings,
            ),
            SizedBox(height: 12),
          ],
          _NetworkCard(peerInfo: _peerInfo),
          SizedBox(height: 12),
          _GatewayCard(
            peerInfo: _peerInfo,
            gatewaysData: widget.gatewaysData,
            onUpdateGateway: widget.onUpdateGateway,
          ),
          SizedBox(height: 12),
          _ProxyCard(
            peerInfo: _peerInfo,
            proxiesData: widget.proxiesData,
            onUpdateProxy: widget.onUpdateProxy,
          ),
          // TODO(redesign): re-enable Services card when more services land here
          // Scaffolding kept in [_ServicesCard] below.
          // SizedBox(height: 12),
          // _ServicesCard(peerInfo: _peerInfo),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  final MyPeerInfo peerInfo;

  const _NetworkCard({required this.peerInfo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stats = peerInfo.networkStats;
    final connected = peerInfo.connectedBootstrapPeers;
    final discoveryLow = connected <= 1;
    // Hide the Discovery row at full health (≥2 connected). With the
    // Online/Offline pill in the header, the row only earns its space
    // when something is wrong or borderline.
    final showDiscoveryRow = discoveryLow;
    final isOnline = connected > 0;

    return _SectionCard(
      header: _CardHeader(
        title: 'Network',
        trailing: StatusPill(
          text: isOnline ? 'Online' : 'Offline',
          color: isOnline ? successColor : errorColor,
        ),
      ),
      // TODO: add 30s sparkline next to Download/Upload speeds when a ring
      // buffer of polled values lives in providers.dart (see plan file).
      children: [
        _StatTile(
          icon: Icons.cloud_download_outlined,
          label: 'Download',
          totalBytes: stats.totalIn,
          rateBytesPerSec: stats.rateIn,
        ),
        _StatTile(
          icon: Icons.cloud_upload_outlined,
          label: 'Upload',
          totalBytes: stats.totalOut,
          rateBytesPerSec: stats.rateOut,
        ),
        _LabeledTile(
          icon: Icons.public_outlined,
          label: 'Reachability',
          subtitle: _reachabilitySubtitle(peerInfo.reachability),
          trailing: _ReachabilityChip(reachability: peerInfo.reachability),
        ),
        if (showDiscoveryRow)
          _LabeledTile(
            icon: Icons.hub_outlined,
            label: 'Discovery nodes',
            subtitle: 'At least 2 nodes recommended for reliable peer discovery.',
            trailing: _BootstrapValue(
              connected: connected,
              total: peerInfo.totalBootstrapPeers,
              errorColor: colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _ProxyCard extends StatelessWidget {
  final MyPeerInfo peerInfo;
  final ListAvailableProxiesResponse? proxiesData;
  final Future<String> Function(String usingPeerID)? onUpdateProxy;

  const _ProxyCard({required this.peerInfo, this.proxiesData, this.onUpdateProxy});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final socks5 = peerInfo.socks5;
    final listenerUp = socks5.listenerEnabled && socks5.listenAddress.isNotEmpty;
    final hasUpstream = socks5.usingPeerID.isNotEmpty;

    String pillText;
    Color pillColor;
    if (!listenerUp) {
      pillText = 'Stopped';
      pillColor = errorColor;
    } else if (hasUpstream && !socks5.connected) {
      pillText = 'Connecting…';
      pillColor = colorScheme.tertiary;
    } else {
      pillText = 'Active';
      pillColor = successColor;
    }

    final proxies = proxiesData?.proxies ?? const <AvailableProxy>[];
    // Empty-state: no candidates AND nothing selected. Listener is up but
    // every connection will fail until a friend allows us — say so plainly
    // instead of rendering a useless one-item dropdown.
    final showEmptyState = listenerUp && proxies.isEmpty && !hasUpstream;

    return _SectionCard(
      header: _CardHeader(
        title: 'SOCKS5 proxy',
        trailing: StatusPill(text: pillText, color: pillColor),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Route specific app traffic through a remote device.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.72)),
          ),
        ),
        if (listenerUp)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: _AddressField(address: socks5.listenAddress),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: showEmptyState
              ? Text(
                  'The proxy listener is running, but no devices offer SOCKS5 exit — '
                  'every connection will fail. Ask a remote device to allow you in their peer settings.',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.72)),
                )
              : _ExitThroughRow(
                  currentName: socks5.usingPeerName,
                  proxiesData: proxiesData,
                  upstreamKnownOffline: hasUpstream && !socks5.connected,
                  usingPublicIP: socks5.usingPeerPublicIP,
                  usingPing: socks5.usingPeerPing,
                  usingThroughRelay: socks5.usingPeerThroughRelay,
                  onUpdateProxy: onUpdateProxy,
                ),
        ),
      ],
    );
  }
}

class _GatewayCard extends StatelessWidget {
  final MyPeerInfo peerInfo;
  final ListAvailableVPNGatewaysResponse? gatewaysData;
  final Future<String> Function(String gatewayPeerID)? onUpdateGateway;

  const _GatewayCard({required this.peerInfo, this.gatewaysData, this.onUpdateGateway});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final gateway = peerInfo.vpnGateway;
    final enabled = gateway.clientEnabled;
    final connected = gateway.connected;

    final pillText = !enabled ? 'Off' : (connected ? 'Active' : 'Connecting…');
    final pillColor = !enabled
        ? colorScheme.onSurfaceVariant
        : (connected ? successColor : colorScheme.tertiary);

    final gateways = gatewaysData?.vpnGateways ?? const <AvailableVPNGateway>[];
    final hasCandidates = gateways.isNotEmpty;

    return _SectionCard(
      header: _CardHeader(
        title: 'VPN Gateway',
        trailing: StatusPill(text: pillText, color: pillColor),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Route all internet traffic through a remote device.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.72)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: hasCandidates || enabled
              ? _GatewayExitRow(
                  selectedPeerID: gateway.gatewayPeerID,
                  selectedName: gateway.gatewayPeerName,
                  gateways: gateways,
                  enabled: enabled,
                  connected: connected,
                  exitPing: gateway.gatewayPing,
                  exitThroughRelay: gateway.gatewayThroughRelay,
                  exitPublicIP: gateway.gatewayPublicIP,
                  onUpdateGateway: onUpdateGateway,
                )
              : Text.rich(
                  TextSpan(
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                    children: const [
                      TextSpan(
                        text:
                            'No devices offer VPN gateway. Ask a remote device to enable '
                            "'Serve as VPN Gateway' on their device, and to allow you in their peer settings.\n",
                      ),
                      TextSpan(text: 'Or open Settings to become a gateway yourself.'),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _GatewayExitRow extends StatelessWidget {
  final String selectedPeerID;
  final String selectedName;
  final List<AvailableVPNGateway> gateways;
  final bool enabled;
  final bool connected;
  final Duration exitPing;
  final bool exitThroughRelay;
  final String exitPublicIP;
  final Future<String> Function(String gatewayPeerID)? onUpdateGateway;

  const _GatewayExitRow({
    required this.selectedPeerID,
    required this.selectedName,
    required this.gateways,
    required this.enabled,
    required this.connected,
    required this.exitPing,
    required this.exitThroughRelay,
    required this.exitPublicIP,
    required this.onUpdateGateway,
  });

  @override
  Widget build(BuildContext context) {
    final options = <_ExitPeerOption>[const _ExitPeerOption('None')];
    for (final n in gateways) {
      options.add(_ExitPeerOption(n.peerName, connected: n.connected));
    }
    var displayName = selectedName.isEmpty ? 'None' : selectedName;
    if (displayName != 'None' && !options.any((o) => o.name == displayName)) {
      // Selection points to a peer not in the candidate list — surface it
      // as a disconnected option so the dropdown stays consistent.
      options.add(_ExitPeerOption(displayName, connected: false));
    }

    Widget? triggerLeading;
    if (enabled && displayName != 'None') {
      triggerLeading = Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _ConnectedDot(connected: connected),
      );
    }

    return _ExitPickerCore(
      options: options,
      selected: displayName,
      triggerLeading: triggerLeading,
      metaLine: enabled && connected
          ? _buildExitMeta(
              context,
              connected: true,
              ping: exitPing,
              throughRelay: exitThroughRelay,
              publicIP: exitPublicIP,
            )
          : null,
      onPick: (picked) => _apply(context, picked),
    );
  }

  Future<void> _apply(BuildContext context, String name) async {
    if (onUpdateGateway == null) return;
    var exitPeerID = '';
    if (name != 'None') {
      final found = gateways.firstWhere(
        (e) => e.peerName == name,
        orElse: () => AvailableVPNGateway('', name, false),
      );
      if (found.peerID.isEmpty) return;
      exitPeerID = found.peerID;
    }
    final response = await onUpdateGateway!(exitPeerID);
    if (!context.mounted) return;
    if (response.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Failed to update VPN gateway: $response'),
        ),
      );
      return;
    }
    // Routing is applied at runtime: onUpdateGateway (in the page adapter) calls
    // reconfigureVpn(), which on Android re-establishes the VPN and hot-swaps the
    // tun fd into the backend. No app restart is required.
  }
}

// TODO(redesign): re-enable when there are more services to show. Kept as
// scaffolding so the third card slot is ready when needed.
// ignore: unused_element
class _ServicesCard extends StatelessWidget {
  final MyPeerInfo peerInfo;

  const _ServicesCard({required this.peerInfo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dnsActive = peerInfo.isAwlDNSSetAsSystem && peerInfo.awlDNSAddress.isNotEmpty;

    return _SectionCard(
      header: const _CardHeader(title: 'Services'),
      children: [
        _LabeledTile(
          icon: Icons.dns_rounded,
          label: 'DNS',
          help: 'AWL DNS resolver for .awl domain names',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dnsActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18,
                color: dnsActive ? colorScheme.primary : colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                dnsActive ? 'Active' : 'Stopped',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: dnsActive ? colorScheme.primary : colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget header;
  final List<Widget> children;

  const _SectionCard({required this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, const SizedBox(height: 4), ...children, const SizedBox(height: 8)],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _CardHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.1),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int totalBytes;
  final double rateBytesPerSec;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.totalBytes,
    required this.rateBytesPerSec,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(label, style: textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${byteCountIEC(rateBytesPerSec.round())}/s', style: textTheme.bodyLarge),
          const SizedBox(width: 8),
          Text(
            '· ${byteCountIEC(totalBytes)}',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _LabeledTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? help;
  final Widget trailing;

  const _LabeledTile({
    required this.icon,
    required this.label,
    required this.trailing,
    this.subtitle,
    this.help,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodyLarge;
    Widget titleWidget = Text(label, style: labelStyle);
    if (help != null) {
      titleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, style: labelStyle)),
          const SizedBox(width: 4),
          Tooltip(
            message: help!,
            child: Icon(Icons.help_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: titleWidget,
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.72)),
            )
          : null,
      trailing: trailing,
    );
  }
}

String? _reachabilitySubtitle(String reachability) {
  switch (reachability) {
    case 'Public':
      return 'Other devices can connect to you directly.';
    case 'Private':
      return 'Other devices reach you via a relay.';
    default:
      return null;
  }
}

class _ReachabilityChip extends StatelessWidget {
  final String reachability;

  const _ReachabilityChip({required this.reachability});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (reachability) {
      case 'Public':
        return const StatusPill(text: 'Public', color: successColor, withDot: false);
      case 'Private':
        return StatusPill(text: 'Private NAT', color: colorScheme.onSurfaceVariant, withDot: false);
      default:
        return StatusPill(text: 'Unknown', color: colorScheme.onSurfaceVariant, withDot: false);
    }
  }
}

class _BootstrapValue extends StatelessWidget {
  final int connected;
  final int total;
  final Color errorColor;

  const _BootstrapValue({required this.connected, required this.total, required this.errorColor});

  @override
  Widget build(BuildContext context) {
    final lowSignal = connected <= 1;
    final color = lowSignal ? errorColor : null;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lowSignal) ...[
          Icon(Icons.warning_amber_rounded, size: 18, color: errorColor),
          const SizedBox(width: 4),
        ],
        Text(
          '$connected / $total',
          style: textTheme.bodyLarge?.copyWith(color: color, fontWeight: lowSignal ? FontWeight.w500 : null),
        ),
      ],
    );
  }
}

class _AddressField extends StatelessWidget {
  final String address;

  const _AddressField({required this.address});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Address',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: border,
        enabledBorder: border,
        contentPadding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy_rounded),
          tooltip: 'Copy address',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: address));
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Address copied to clipboard')));
          },
        ),
      ),
      child: SelectableText(address, style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
    );
  }
}

class _ExitThroughRow extends StatelessWidget {
  final String currentName;
  final ListAvailableProxiesResponse? proxiesData;
  final bool upstreamKnownOffline;
  final String usingPublicIP;
  final Duration usingPing;
  final bool usingThroughRelay;
  final Future<String> Function(String usingPeerID)? onUpdateProxy;

  const _ExitThroughRow({
    required this.currentName,
    required this.proxiesData,
    required this.upstreamKnownOffline,
    required this.usingPublicIP,
    required this.usingPing,
    required this.usingThroughRelay,
    required this.onUpdateProxy,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = currentName.isEmpty ? 'None' : currentName;
    final options = <_ExitPeerOption>[const _ExitPeerOption('None')];
    if (proxiesData != null) {
      for (final p in proxiesData!.proxies) {
        options.add(_ExitPeerOption(p.peerName, connected: p.connected));
      }
    }
    if (displayName != 'None' && !options.any((o) => o.name == displayName)) {
      options.add(_ExitPeerOption(displayName, connected: false));
    }

    Widget? triggerLeading;
    if (displayName != 'None') {
      triggerLeading = Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _ConnectedDot(connected: !upstreamKnownOffline),
      );
    }

    return _ExitPickerCore(
      options: options,
      selected: displayName,
      triggerLeading: triggerLeading,
      metaLine: !upstreamKnownOffline
          ? _buildExitMeta(
              context,
              connected: true,
              ping: usingPing,
              throughRelay: usingThroughRelay,
              publicIP: usingPublicIP,
            )
          : null,
      onPick: (picked) => _apply(context, picked),
    );
  }

  Future<void> _apply(BuildContext context, String name) async {
    if (onUpdateProxy == null) return;
    var usingPeerID = '';
    if (name != 'None') {
      final proxies = proxiesData;
      if (proxies == null) return;
      final found = proxies.proxies.firstWhere(
        (e) => e.peerName == name,
        orElse: () => AvailableProxy('', name, false),
      );
      usingPeerID = found.peerID;
    }
    final response = await onUpdateProxy!(usingPeerID);
    if (!context.mounted) return;
    if (response.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Failed to update proxy settings: $response'),
        ),
      );
    }
  }
}

/// One option in the exit-peer picker. [connected] is `null` for entries
/// that have no online/offline meaning (e.g. "None"); a `bool` value is
/// rendered as a green/dim leading dot in items.
class _ExitPeerOption {
  final String name;
  final bool? connected;

  const _ExitPeerOption(this.name, {this.connected});
}

/// Small leading dot rendered for items that carry an online/offline state.
/// Solid green for connected peers, dim hollow for disconnected.
class _ConnectedDot extends StatelessWidget {
  final bool connected;

  const _ConnectedDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Icon(
      connected ? Icons.circle : Icons.circle_outlined,
      size: 10,
      color: connected ? successColor : colorScheme.onSurfaceVariant,
    );
  }
}

/// Shared layout for the SOCKS5 / VPN-Gateway exit-peer pickers:
///
///   [ Exit peer ────────────────────────────────────────── ]
///   [ ● awl-tester                                       ▼ ]
///   ● Direct · 21 ms · Public IP: 203.0.113.45
///
/// Full-width dropdown matches the [_AddressField] pattern in the same
/// card — both are Material outlined inputs with a floating label, so the
/// card reads as one consistent form. Optional [metaLine] sits inline
/// below. The two cards differ in their data sources, async update
/// endpoints, and success-side-effects — those stay in the per-card
/// wrappers; this widget owns only the visual composition.
class _ExitPickerCore extends StatelessWidget {
  final List<_ExitPeerOption> options;
  final String selected;
  final Widget? triggerLeading;
  final Widget? metaLine;
  final Future<void> Function(String pickedName) onPick;

  const _ExitPickerCore({
    required this.options,
    required this.selected,
    required this.triggerLeading,
    required this.metaLine,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ExitPeerDropdown(options: options, selected: selected, leading: triggerLeading, onPick: onPick),
        if (metaLine != null) ...[const SizedBox(height: 8), metaLine!],
      ],
    );
  }
}

class _ExitPeerDropdown extends StatelessWidget {
  final List<_ExitPeerOption> options;
  final String selected;
  final Widget? leading;
  final Future<void> Function(String) onPick;

  const _ExitPeerDropdown({
    required this.options,
    required this.selected,
    required this.onPick,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    final trigger = InputDecorator(
      decoration: InputDecoration(
        labelText: 'Exit peer',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
        border: border,
        enabledBorder: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?leading,
          Expanded(
            child: Text(
              selected,
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.arrow_drop_down_rounded, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );

    if (isMobile) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await _showExitPeerSheet(context, options, selected);
          if (picked == null || picked == selected) return;
          if (!context.mounted) return;
          await onPick(picked);
        },
        child: trigger,
      );
    }

    return PopupMenuButton<String>(
      tooltip: '',
      initialValue: selected,
      onSelected: onPick,
      itemBuilder: (_) => options
          .map(
            (o) => PopupMenuItem<String>(
              value: o.name,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (o.connected != null) ...[
                    _ConnectedDot(connected: o.connected!),
                    const SizedBox(width: 10),
                  ],
                  Text(o.name),
                ],
              ),
            ),
          )
          .toList(),
      child: trigger,
    );
  }

  Future<String?> _showExitPeerSheet(BuildContext context, List<_ExitPeerOption> options, String selected) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Exit through', style: Theme.of(context).textTheme.titleMedium),
              ),
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) => Navigator.of(context).pop(value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options
                      .map(
                        (o) => RadioListTile<String>(
                          value: o.name,
                          title: Row(
                            children: [
                              if (o.connected != null) ...[
                                _ConnectedDot(connected: o.connected!),
                                const SizedBox(width: 12),
                              ],
                              Expanded(child: Text(o.name)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// One-line live metadata about the active exit, shown below the picker:
/// colored leading dot (green for direct, amber for via-relay), mode + ping,
/// and the observed Public IP — joined with " · ". Wraps on narrow widths.
/// Returns `null` when there's nothing to show (e.g. not connected and no IP).
Widget? _buildExitMeta(
  BuildContext context, {
  required bool connected,
  required Duration ping,
  required bool throughRelay,
  required String publicIP,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final baseStyle = textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.85));
  final dimStyle = textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.72));

  String? modePing;
  Color? dotColor;
  if (connected) {
    final mode = throughRelay ? 'Via relay' : 'Direct';
    final ms = ping.inMilliseconds;
    modePing = ms > 0 ? '$mode · $ms ms' : mode;
    dotColor = throughRelay ? warningColor : successColor;
  }

  if (modePing == null && publicIP.isEmpty) return null;

  // Multiple separate widgets (vs Text.rich) so widget tests can find each
  // segment with `find.text(...)`. Wrap keeps it visually inline.
  final children = <Widget>[];
  if (dotColor != null) {
    children.add(
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      ),
    );
    children.add(const SizedBox(width: 8));
  }
  if (modePing != null) {
    children.add(Text(modePing, style: baseStyle));
  }
  if (modePing != null && publicIP.isNotEmpty) {
    children.add(Text(' · ', style: dimStyle));
  }
  if (publicIP.isNotEmpty) {
    children.add(Text('Public IP: ', style: dimStyle));
    children.add(SelectableText(publicIP, style: baseStyle?.copyWith(fontFamily: 'monospace')));
  }

  return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: children);
}

Widget buildDeviceHeader(
  BuildContext context,
  MyPeerInfo peerInfo, {
  VoidCallback? onShowQR,
  VoidCallback? onShowSettings,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Row(
    children: [
      Icon(Icons.laptop_mac_rounded, size: 34, color: colorScheme.primary),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              peerInfo.name.isNotEmpty ? peerInfo.name : 'This Device',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              '${peerInfo.serverVersion} · uptime ${formatDuration(peerInfo.uptime)}',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      if (onShowQR != null) ...[
        IconButton.filledTonal(
          icon: const Icon(Icons.qr_code_rounded),
          tooltip: 'My ID',
          onPressed: onShowQR,
        ),
        const SizedBox(width: 8),
      ],
      if (onShowSettings != null)
        IconButton.filledTonal(
          icon: const Icon(Icons.settings_rounded),
          tooltip: 'Settings',
          onPressed: onShowSettings,
        ),
    ],
  );
}

Future<void> showSettingsDialog(BuildContext context, MyPeerInfo? peerInfo, bool firstSetup) {
  return showDialog(
    context: context,
    barrierDismissible: !firstSetup,
    builder: (context) {
      return SimpleDialog(
        title: Text("Settings"),
        children: [
          Center(
            child: SizedBox(width: 350, child: SettingsForm(peerInfo: peerInfo)),
          ),
        ],
      );
    },
  );
}

class SettingsForm extends ConsumerStatefulWidget {
  final MyPeerInfo? peerInfo;

  const SettingsForm({super.key, this.peerInfo});

  @override
  ConsumerState<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<SettingsForm> {
  TextEditingController? _peerNameTextController;
  final _formKey = GlobalKey<FormState>();

  String _serverError = "";

  void _onPressSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var response = await ref.read(apiProvider).updateMySettings(_peerNameTextController!.text);
    if (!mounted) return;
    if (response == "") {
      Navigator.pop(context);
      _serverError = "";
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Successfully saved")));
    } else {
      _serverError = response;
      _formKey.currentState!.validate();
      _serverError = "";
    }
  }

  @override
  void initState() {
    super.initState();

    _peerNameTextController = TextEditingController(text: widget.peerInfo!.name);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _peerNameTextController,
              decoration: InputDecoration(labelText: 'Your peer name'),
              validator: (value) {
                if (value!.isEmpty) {
                  return 'Please enter peer name';
                } else if (_serverError != "") {
                  return _serverError;
                }
                return null;
              },
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
            ),
          ),
          _BeGatewaySwitch(initial: widget.peerInfo?.vpnGateway.serverEnabled ?? false),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                child: Text('Cancel'),
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
              SizedBox(width: 20),
              ElevatedButton(
                child: Text('Save'),
                onPressed: () async {
                  _onPressSave();
                },
              ),
            ],
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// "Serve as VPN Gateway" toggle. Lives inside [SettingsForm] but applies its
/// own state independently — the backend has a dedicated endpoint and
/// flipping this is rare and consequential, so we don't bundle it with the
/// peer-name save button.
class _BeGatewaySwitch extends ConsumerStatefulWidget {
  final bool initial;

  const _BeGatewaySwitch({required this.initial});

  @override
  ConsumerState<_BeGatewaySwitch> createState() => _BeGatewaySwitchState();
}

class _BeGatewaySwitchState extends ConsumerState<_BeGatewaySwitch> {
  late bool _value = widget.initial;
  bool _busy = false;

  bool get _androidUnsupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _toggle(bool next) async {
    if (_busy) return;
    if (next) {
      final ok = await _confirm();
      if (ok != true) return;
    }
    setState(() => _busy = true);
    final response = await ref.read(apiProvider).setVPNGatewayServerEnabled(next);
    if (!mounted) return;
    setState(() => _busy = false);
    if (response.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('Failed to update VPN gateway mode: $response'),
        ),
      );
      return;
    }
    setState(() => _value = next);
    await ref.read(myPeerInfoProvider.notifier).refresh();
  }

  Future<bool?> _confirm() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Serve as VPN Gateway'),
        content: const Text(
          'Devices you permit will be able to route their internet traffic through this device. '
          'Their traffic will appear to come from your IP address. Make sure you trust them.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enable')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = _androidUnsupported || _busy;
    final tile = SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Row(
        children: [
          const Flexible(child: Text('Serve as VPN Gateway')),
          if (_androidUnsupported) ...[
            const SizedBox(width: 6),
            Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              message:
                  'Not supported on Android: serving as a VPN gateway requires '
                  "NAT/iptables configuration that Android apps can't perform without root.",
              child: Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
      subtitle: Text(
        _androidUnsupported
            ? 'Not supported on Android.'
            : 'Let permitted devices route their internet traffic through this device.',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      value: _androidUnsupported ? false : _value,
      onChanged: disabled ? null : _toggle,
    );
    return tile;
  }
}
