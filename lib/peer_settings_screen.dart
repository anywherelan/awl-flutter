import 'dart:async';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class KnownPeerSettingsScreen extends StatefulWidget {
  static String routeName = "/peer_settings";

  KnownPeerSettingsScreen({Key? key}) : super(key: key);

  @override
  _KnownPeerSettingsScreenState createState() => _KnownPeerSettingsScreenState();
}

class _KnownPeerSettingsScreenState extends State<KnownPeerSettingsScreen> {
  late TextEditingController _aliasTextController;
  late TextEditingController _domainNameTextController;
  late bool _weAllowUsingAsExitNode;

  bool _hasPeerConfig = false;
  late String _peerID;
  late KnownPeerConfig _peerConfig;
  late String _peerDisplayName;

  final _generalFormKey = GlobalKey<FormState>();

  void _refreshPeerConfig() async {
    var peerConfig = await fetchKnownPeerConfig(http.Client(), _peerID);
    if (!this.mounted) {
      return;
    }

    _aliasTextController = TextEditingController(text: peerConfig.alias);
    _domainNameTextController = TextEditingController(text: peerConfig.domainName);
    _weAllowUsingAsExitNode = peerConfig.weAllowUsingAsExitNode;

    setState(() {
      _peerConfig = peerConfig;
      _peerDisplayName = _peerConfig.alias != "" ? _peerConfig.alias : _peerConfig.name;
    });
  }

  Future<String> _sendNewPeerConfig() async {
    var payload = UpdateKnownPeerConfigRequest(
        _peerConfig.peerId, _aliasTextController.text, _domainNameTextController.text, _weAllowUsingAsExitNode);

    var response = await updateKnownPeerConfig(http.Client(), payload);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPeerConfig) {
      _peerID = ModalRoute.of(context)!.settings.arguments as String;

      _refreshPeerConfig();
      _hasPeerConfig = true;
      return Container();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
          ),
          child: ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              _buildGeneralForm(),
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextButton(
                    child: Text('REMOVE PEER'),
                    onPressed: () async {
                      _removePeer(context);
                    },
                  ),
                  SizedBox(width: 80),
                  ElevatedButton(
                    child: Text('CANCEL'),
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    child: Text('SAVE'),
                    onPressed: () async {
                      var result = await _sendNewPeerConfig();
                      if (result == "") {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Colors.green,
                          content: Text("Successfully saved"),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Colors.red,
                          content: Text(result),
                        ));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralForm() {
    return Form(
      key: _generalFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              initialValue: _peerConfig.peerId,
              decoration: InputDecoration(labelText: 'Peer ID', enabled: false),
              maxLines: 2,
              minLines: 1,
              readOnly: true,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              initialValue: _peerConfig.ipAddr,
              decoration: InputDecoration(labelText: 'Local address', enabled: false),
              maxLines: 2,
              minLines: 1,
              readOnly: true,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              initialValue: _peerConfig.name,
              decoration: InputDecoration(labelText: 'Name', enabled: false),
              readOnly: true,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _aliasTextController,
              decoration: InputDecoration(labelText: 'Alias'),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _domainNameTextController,
              autovalidateMode: AutovalidateMode.always,
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return null;
                }
                var filteredValue = value.trim().replaceAll(RegExp(r'\s'), "").toLowerCase();
                if (value != filteredValue) {
                  return "should be lowercase and without whitespace";
                }

                return null;
              },
              decoration: InputDecoration(
                labelText: 'Domain name',
                helperText: 'domain name without ".awl" suffix, like "tvbox.home" or "workstation"',
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: FormField(
                initialValue: false,
                builder: (FormFieldState<bool> state) {
                  return CheckboxListTile(
                      title: const Text("Allow to use my device as exit node", textAlign: TextAlign.left),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Tooltip(
                          triggerMode: TooltipTriggerMode.tap,
                          message:
                              'This allows peer to pass their traffic through your network via SOCKS5 proxy, for instance peer will have access to your local WiFi network',
                          child: Icon(Icons.info),
                        ),
                      ),
                      value: _weAllowUsingAsExitNode,
                      onChanged: (val) {
                        setState(() {
                          _weAllowUsingAsExitNode = val!;
                        });
                      });
                }),
          )
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
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
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
        backgroundColor: Colors.red,
        content: Text("Failed to remove peer: $response"),
      ));
      return;
    }

    knownPeersDataService.fetchData();
    Navigator.pop(context);
  }
}
