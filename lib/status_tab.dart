import 'dart:async';

import 'package:anywherelan/common.dart';
import 'package:anywherelan/connection_error.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
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
          showDeviceHeader: widget.showDeviceHeader,
          onUpdateProxy: _onUpdateProxy,
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
  final bool showDeviceHeader;
  final Future<String> Function(String usingPeerID)? onUpdateProxy;
  final Future<void> Function()? onShowQR;
  final Future<void> Function()? onShowSettings;

  const StatusPageView({
    super.key,
    required this.peerInfo,
    this.proxiesData,
    this.showDeviceHeader = true,
    this.onUpdateProxy,
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
    final discoveryLow = peerInfo.connectedBootstrapPeers <= 1;

    return _SectionCard(
      header: const _CardHeader(title: 'Network'),
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
        _LabeledTile(
          icon: Icons.hub_outlined,
          label: 'Discovery nodes',
          subtitle: discoveryLow ? 'At least 2 nodes recommended for reliable peer discovery.' : null,
          trailing: _BootstrapValue(
            connected: peerInfo.connectedBootstrapPeers,
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
    final isActive = peerInfo.socks5.listenerEnabled && peerInfo.socks5.listenAddress.isNotEmpty;

    return _SectionCard(
      header: _CardHeader(
        title: 'SOCKS5 proxy',
        trailing: StatusPill(
          text: isActive ? 'Active' : 'Stopped',
          color: isActive ? successColor : errorColor,
        ),
      ),
      children: [
        if (isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _AddressField(address: peerInfo.socks5.listenAddress),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: _ExitThroughRow(
            currentName: peerInfo.socks5.usingPeerName,
            proxiesData: proxiesData,
            onUpdateProxy: onUpdateProxy,
          ),
        ),
      ],
    );
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
      subtitle: Text(
        '${byteCountIEC(totalBytes)} total',
        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.72)),
      ),
      trailing: Text('${byteCountIEC(rateBytesPerSec.round())}/s', style: textTheme.bodyLarge),
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
      return 'Other peers can connect to you directly.';
    case 'Private':
      return 'Other peers reach you via a relay.';
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
  final Future<String> Function(String usingPeerID)? onUpdateProxy;

  const _ExitThroughRow({required this.currentName, required this.proxiesData, required this.onUpdateProxy});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final displayName = currentName.isEmpty ? 'None' : currentName;
    final names = <String>['None'];
    if (proxiesData != null) {
      for (final p in proxiesData!.proxies) {
        names.add(p.peerName);
      }
    }
    if (displayName != 'None' && !names.contains(displayName)) {
      names.add(displayName);
    }

    final labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Exit through', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          'Proxied traffic leaves the internet from this peer.',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.72)),
        ),
      ],
    );

    final dropdown = _ExitPeerDropdown(
      names: names,
      selected: displayName,
      onPick: (picked) => _apply(context, picked),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labelColumn, const SizedBox(height: 10), dropdown],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: labelColumn),
            const SizedBox(width: 12),
            SizedBox(width: 180, child: dropdown),
          ],
        );
      },
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
        orElse: () => AvailableProxy('', name),
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

class _ExitPeerDropdown extends StatelessWidget {
  final List<String> names;
  final String selected;
  final Future<void> Function(String) onPick;

  const _ExitPeerDropdown({required this.names, required this.selected, required this.onPick});

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
          final picked = await _showExitPeerSheet(context, names, selected);
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
      itemBuilder: (_) => names.map((n) => PopupMenuItem<String>(value: n, child: Text(n))).toList(),
      child: trigger,
    );
  }

  Future<String?> _showExitPeerSheet(BuildContext context, List<String> names, String selected) {
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
                  children: names.map((n) => RadioListTile<String>(title: Text(n), value: n)).toList(),
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
        ],
      ),
    );
  }
}
