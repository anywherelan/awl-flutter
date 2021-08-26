import 'dart:async';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class KnownPeerSettingsScreen extends StatefulWidget {
  KnownPeerSettingsScreen({Key? key}) : super(key: key);

  @override
  _KnownPeerSettingsScreenState createState() => _KnownPeerSettingsScreenState();
}

class _KnownPeerSettingsScreenState extends State<KnownPeerSettingsScreen> {
  TextEditingController _aliasTextController = TextEditingController();

  late String _peerID;
  KnownPeerConfig? _peerConfig;

  final _generalFormKey = GlobalKey<FormState>();

  void _refreshPeerConfig() async {
    var peerConfig = await fetchKnownPeerConfig(http.Client(), _peerID);
    if (!this.mounted) {
      return;
    }

    _aliasTextController = TextEditingController(text: peerConfig.alias);

    setState(() {
      _peerConfig = peerConfig;
    });
  }

  Future<String?> _sendNewPeerConfig() async {
    var payload = UpdateKnownPeerConfigRequest(_peerConfig!.peerId, _aliasTextController.text);

    var response = await updateKnownPeerConfig(http.Client(), payload);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    if (_peerConfig == null) {
      _peerID = ModalRoute.of(context)!.settings.arguments as String;

      _refreshPeerConfig();
      return Container();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            Center(child: Text('General', style: Theme.of(context).textTheme.headline5)),
            _buildGeneralForm(),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(
                  child: Text('Cancel'),
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                ),
                SizedBox(width: 20),
                RaisedButton(
                  child: Text('Save'),
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
                        content: Text(result!),
                      ));
                    }
                  },
                ),
              ],
            ),
          ],
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
              initialValue: _peerConfig!.peerId,
              decoration: InputDecoration(labelText: 'Peer ID', enabled: false),
              maxLines: 2,
              minLines: 1,
              readOnly: true,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              initialValue: _peerConfig!.ipAddr,
              decoration: InputDecoration(labelText: 'Local address', enabled: false),
              maxLines: 2,
              minLines: 1,
              readOnly: true,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              initialValue: _peerConfig!.name,
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
        ],
      ),
    );
  }
}
