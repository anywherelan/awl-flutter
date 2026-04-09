import 'dart:async';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class KnownPeerSettingsScreen extends StatefulWidget {
  static String routeFor(String peerId) => '/peers/$peerId/settings';

  static String peerIdFromRoute(String route) {
    final segments = Uri
        .parse(route)
        .pathSegments;
    // segments: ['peers', peer_id, 'settings']
    return segments[1];
  }

  KnownPeerSettingsScreen({Key? key}) : super(key: key);

  @override
  _KnownPeerSettingsScreenState createState() => _KnownPeerSettingsScreenState();
}

class _KnownPeerSettingsScreenState extends State<KnownPeerSettingsScreen> {
  late TextEditingController _aliasTextController;
  late TextEditingController _domainNameTextController;
  late TextEditingController _ipAddrTextController;
  late bool _weAllowUsingAsExitNode;

  bool _hasPeerConfig = false;
  String? _loadError;
  late String _peerID;
  late KnownPeerConfig _peerConfig;
  late String _peerDisplayName;

  final _generalFormKey = GlobalKey<FormState>();

  void _refreshPeerConfig() async {
    try {
      var peerConfig = await fetchKnownPeerConfig(http.Client(), _peerID);
      if (!this.mounted) {
        return;
      }

      _aliasTextController = TextEditingController(text: peerConfig.alias);
      _domainNameTextController = TextEditingController(text: peerConfig.domainName);
      _ipAddrTextController = TextEditingController(text: peerConfig.ipAddr);
      _weAllowUsingAsExitNode = peerConfig.weAllowUsingAsExitNode;

      setState(() {
        _peerConfig = peerConfig;
        _peerDisplayName = _peerConfig.alias != "" ? _peerConfig.alias : _peerConfig.name;
      });
    } catch (e) {
      if (!this.mounted) {
        return;
      }
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<String> _sendNewPeerConfig() async {
    var payload = UpdateKnownPeerConfigRequest(
        _peerConfig.peerId, _aliasTextController.text, _domainNameTextController.text, _ipAddrTextController.text,
        _weAllowUsingAsExitNode);

    var response = await updateKnownPeerConfig(http.Client(), payload);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPeerConfig) {
      _peerID = KnownPeerSettingsScreen.peerIdFromRoute(ModalRoute
          .of(context)!
          .settings
          .name!);

      _refreshPeerConfig();
      _hasPeerConfig = true;
      return Container();
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Peer settings')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, style: TextStyle(color: Theme
                  .of(context)
                  .colorScheme
                  .error)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme
        .of(context)
        .colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              _buildGeneralForm(),
              SizedBox(height: 40),
              _buildDangerZone(colorScheme),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            SizedBox(width: 12),
            FilledButton(
              child: Text('Save changes'),
              onPressed: () async {
                if (!_generalFormKey.currentState!.validate()) {
                  return;
                }
                var result = await _sendNewPeerConfig();
                if (result == "") {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Successfully saved"),
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: colorScheme.error,
                    content: Text(result),
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme
              .of(context)
              .colorScheme
              .onSurfaceVariant, letterSpacing: 0.5)),
          SizedBox(height: 8),
          Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildDangerZone(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, size: 18, color: colorScheme.error),
              SizedBox(width: 8),
              Text('Danger zone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.error)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Removing this peer will disconnect it permanently. You will need to re-add them to reconnect.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.delete, size: 18),
            label: Text('Remove peer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
            ),
            onPressed: () => _removePeer(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralForm() {
    return Form(
      key: _generalFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity section
          _buildSectionTitle('IDENTITY'),
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: TextFormField(
              initialValue: _peerConfig.name,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: 'Original name chosen by this peer',
                helperMaxLines: 2,
                filled: false,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: TextFormField(
              initialValue: _peerConfig.peerId,
              readOnly: true,
              style: TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Peer ID',
                helperText: 'Unique identifier used to connect to this peer. Also serves as a cryptographic public key for end-to-end encryption.',
                helperMaxLines: 3,
                filled: false,
                suffixIcon: IconButton(
                  icon: Icon(Icons.content_copy),
                  tooltip: 'Copy Peer ID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _peerConfig.peerId));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Peer ID copied to clipboard")));
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: TextFormField(
              controller: _aliasTextController,
              decoration: InputDecoration(labelText: 'Alias', filled: true),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: TextFormField(
              controller: _domainNameTextController,
              autovalidateMode: AutovalidateMode.always,
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter domain';
                }
                var filteredValue = value.trim().replaceAll(RegExp(r'\s'), "").toLowerCase();
                if (value != filteredValue) {
                  return "should be lowercase and without whitespace";
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Domain name',
                helperText: 'Without ".awl" suffix, like "tvbox.home" or "workstation"',
                filled: true,
              ),
            ),
          ),

          // Network section
          _buildSectionTitle('NETWORK'),
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: TextFormField(
              controller: _ipAddrTextController,
              decoration: InputDecoration(
                labelText: 'Local IP address',
                helperText: 'Example: 10.66.0.2',
                filled: true,
              ),
              autovalidateMode: AutovalidateMode.onUnfocus,
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an IP address';
                }

                try {
                  // TODO: support ipv6
                  Uri.parseIPv4Address(value);
                  return null;
                } catch (e) {
                  return 'Invalid IPv4 address format';
                }
              },
            ),
          ),

          // Permissions section
          _buildSectionTitle('PERMISSIONS'),
          Row(
            children: [
              Icon(Icons.vpn_key, color: Theme
                  .of(context)
                  .colorScheme
                  .onSurfaceVariant),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allow as exit node', style: TextStyle(fontSize: 16)),
                    Text('Allow this peer to route traffic through your network',
                        style: TextStyle(fontSize: 13, color: Theme
                            .of(context)
                            .colorScheme
                            .onSurfaceVariant)),
                  ],
                ),
              ),
              Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message: 'This allows peer to pass their traffic through your network via SOCKS5 proxy, for instance peer will have access to your local WiFi network',
                child: IconButton(
                  icon: Icon(Icons.info_outline, size: 20),
                  onPressed: null,
                  color: Theme
                      .of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
              Switch(
                value: _weAllowUsingAsExitNode,
                onChanged: (val) {
                  setState(() {
                    _weAllowUsingAsExitNode = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _removePeer(BuildContext context) async {
    var permitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove Peer'),
        content: Text('Are you sure you want to remove peer "$_peerDisplayName"?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme
                  .of(context)
                  .colorScheme
                  .error,
              foregroundColor: Theme
                  .of(context)
                  .colorScheme
                  .onError,
            ),
          ),
        ],
      ),
    );

    if (permitted == null || permitted == false) {
      return;
    }

    var response = await removePeer(http.Client(), _peerID);
    if (response != "") {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .error,
        content: Text("Failed to remove peer: $response"),
      ));
      return;
    }

    knownPeersDataService.fetchData();
    Navigator.pop(context);
  }
}
