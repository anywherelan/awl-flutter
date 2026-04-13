import 'dart:async';

import 'package:anywherelan/common.dart';
import 'package:anywherelan/connection_error.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adapter for [StatusPageView] that reads [myPeerInfoProvider] and
/// [availableProxiesProvider] via Riverpod. The pure presentation logic
/// lives in [StatusPageView].
class StatusPage extends ConsumerStatefulWidget {
  const StatusPage({super.key});

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
  final Future<String> Function(String usingPeerID)? onUpdateProxy;
  final Future<void> Function()? onShowQR;
  final Future<void> Function()? onShowSettings;

  const StatusPageView({
    super.key,
    required this.peerInfo,
    this.proxiesData,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Device header
          SizedBox(height: 4),
          _buildDeviceHeader(context),
          SizedBox(height: 12),
          ..._buildSections(context),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.tonalIcon(
                icon: Icon(Icons.qr_code, size: 18),
                label: Text("My ID"),
                onPressed: () => widget.onShowQR?.call(),
              ),
              SizedBox(width: 12),
              OutlinedButton.icon(
                icon: Icon(Icons.settings, size: 18),
                label: Text("Settings"),
                onPressed: () => widget.onShowSettings?.call(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.computer, size: 24, color: colorScheme.primary),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _peerInfo.name.isNotEmpty ? _peerInfo.name : 'This Device',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_peerInfo.serverVersion} · up ${formatDuration(_peerInfo.uptime)}',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        Divider(height: 20, color: colorScheme.outlineVariant),
      ],
    );
  }

  Widget _buildStatusChip(String text, Color textColor, Color bgColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    var reachabilityText = "Unknown";
    var reachabilityColor = unknownStatusColor(context);
    switch (_peerInfo.reachability) {
      case "Public":
        reachabilityText = "Public";
        reachabilityColor = successColor;
        break;
      case "Private":
        reachabilityText = "Private";
        reachabilityColor = warningColor;
        break;
      default:
        reachabilityText = "Unknown";
    }

    String dnsText;
    Color dnsColor;
    if (_peerInfo.isAwlDNSSetAsSystem && _peerInfo.awlDNSAddress != "") {
      dnsText = "Working";
      dnsColor = successColor;
    } else {
      dnsText = "Not working";
      dnsColor = errorColor;
    }

    String socks5Text;
    Color socks5Color;
    if (_peerInfo.socks5.listenerEnabled && _peerInfo.socks5.listenAddress != "") {
      socks5Text = "Working";
      socks5Color = successColor;
    } else {
      socks5Text = "Not working";
      socks5Color = errorColor;
    }

    String bootstrapText = "${_peerInfo.connectedBootstrapPeers}/${_peerInfo.totalBootstrapPeers}";
    Color bootstrapColor;
    if (_peerInfo.connectedBootstrapPeers == 0) {
      bootstrapColor = errorColor;
    } else if (_peerInfo.connectedBootstrapPeers <= _peerInfo.totalBootstrapPeers * 0.6) {
      bootstrapColor = warningColor;
    } else {
      bootstrapColor = successColor;
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Map semantic colors to vivid chip color pairs (text, background)
    (Color, Color) chipColors(Color semanticColor) {
      if (semanticColor == successColor) {
        return (const Color(0xFF0A5420), const Color(0xFFD4EDDA));
      } else if (semanticColor == warningColor) {
        return (const Color(0xFF7A5A00), const Color(0xFFFFF3CD));
      } else if (semanticColor == errorColor) {
        return (colorScheme.onErrorContainer, colorScheme.errorContainer);
      }
      return (colorScheme.onSecondaryContainer, colorScheme.secondaryContainer);
    }

    return [
      // Network section
      _buildSectionHeader('NETWORK'),
      _buildBodyItemText(Icons.cloud_download_outlined, "Download", _peerInfo.networkStats.inAsString()),
      _buildBodyItemText(Icons.cloud_upload_outlined, "Upload", _peerInfo.networkStats.outAsString()),
      _buildBodyItemWidget(
        Icons.wifi_tethering,
        "Reachability",
        _buildStatusChip(
          reachabilityText,
          chipColors(reachabilityColor).$1,
          chipColors(reachabilityColor).$2,
        ),
        tooltip:
            "Whether this device can be reached directly. Public = direct connections, Private = connections go through relays",
      ),
      _buildBodyItemWidget(
        Icons.hub_outlined,
        "Bootstrap peers",
        _buildStatusChip(bootstrapText, chipColors(bootstrapColor).$1, chipColors(bootstrapColor).$2),
        tooltip: "Connected bootstrap nodes used for peer discovery, should be at least 1",
      ),

      // Services section
      _buildSectionHeader('SERVICES'),
      _buildBodyItemWidget(
        Icons.dns_outlined,
        "DNS",
        _buildStatusChip(dnsText, chipColors(dnsColor).$1, chipColors(dnsColor).$2),
        tooltip: "AWL DNS resolver for .awl domain names",
      ),
      _buildBodyItemWidget(
        Icons.router_outlined,
        "SOCKS5 Proxy",
        _buildStatusChip(socks5Text, chipColors(socks5Color).$1, chipColors(socks5Color).$2),
        tooltip: "SOCKS5 proxy for routing traffic through a peer's network",
      ),
      if (_peerInfo.socks5.listenerEnabled)
        _buildBodyItemText(Icons.link, "Proxy address", _peerInfo.socks5.listenAddress),
      _buildProxySelectorWidget("Proxy exit peer"),
    ];
  }

  Widget _buildBodyItemText(IconData icon, String label, String text, {Color? textColor, String? tooltip}) {
    return _buildBodyItemWidget(
      icon,
      label,
      SelectableText(text, style: TextStyle(color: textColor)),
      tooltip: tooltip,
    );
  }

  Widget _buildBodyItemWidget(IconData icon, String label, Widget child, {String? tooltip}) {
    const double wideScreenBreakpoint = 800.0;
    final bool isWideScreen = MediaQuery.of(context).size.width > wideScreenBreakpoint;
    final verticalPadding = isWideScreen ? 4.0 : 6.0;

    Widget labelWidget = Text(label);
    if (tooltip != null) {
      labelWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          SizedBox(width: 4),
          Tooltip(
            message: tooltip,
            child: Icon(Icons.help_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: verticalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon), SizedBox(width: 10), labelWidget, SizedBox(width: 30)]),
          Flexible(fit: FlexFit.loose, child: child),
        ],
      ),
    );
  }

  Widget _buildProxySelectorWidget(String label) {
    var socks5UsingPeer = _peerInfo.socks5.usingPeerName;
    if (socks5UsingPeer == "") {
      socks5UsingPeer = "None";
    }

    List<String> socks5PeersList = <String>['None'];
    final proxiesData = widget.proxiesData;
    if (proxiesData != null) {
      for (var proxy in proxiesData.proxies) {
        socks5PeersList.add(proxy.peerName);
      }
    }

    if (socks5UsingPeer != "" && socks5UsingPeer != "None" && !socks5PeersList.contains(socks5UsingPeer)) {
      // in case when peer info data and available proxies data are not in sync
      socks5PeersList.add(socks5UsingPeer);
    }

    return _buildBodyItemWidget(
      Icons.exit_to_app,
      label,
      PopupMenuButton<String>(
        tooltip: '',
        initialValue: socks5UsingPeer,
        onSelected: (String value) async {
          if (widget.onUpdateProxy == null) return;
          var usingPeerName = value;
          var usingPeerID = "";
          if (usingPeerName != "None") {
            final proxies = widget.proxiesData;
            if (proxies == null) return;
            var found = proxies.proxies.firstWhere((element) => element.peerName == usingPeerName);
            usingPeerID = found.peerID;
          }

          var response = await widget.onUpdateProxy!(usingPeerID);
          if (!mounted) return;
          if (response != "") {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).colorScheme.error,
                content: Text("Failed to update proxy settings: $response"),
              ),
            );
            return;
          }
        },
        itemBuilder: (context) => socks5PeersList.map((String value) {
          return PopupMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 2),
              Text(socks5UsingPeer, style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Icon(Icons.arrow_drop_down, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
      tooltip: "Peer used as the exit point for SOCKS5 proxy traffic",
    );
  }
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
