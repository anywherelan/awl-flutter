import 'package:flutter/material.dart';
import 'package:peerlanflutter/entities.dart';
import 'package:peerlanflutter/api.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';

class KnownPeerSettingsScreen extends StatefulWidget {
  KnownPeerSettingsScreen({Key key}) : super(key: key);

  @override
  _KnownPeerSettingsScreenState createState() => _KnownPeerSettingsScreenState();
}

class _KnownPeerSettingsScreenState extends State<KnownPeerSettingsScreen> {
  TextEditingController _aliasTextController = TextEditingController();
  TextEditingController _addNewLocalPortController = TextEditingController();

  String _peerID;
  KnownPeerConfig _peerConfig;

  var _scaffoldKey = new GlobalKey<ScaffoldState>();

  final _generalFormKey = GlobalKey<FormState>();
  final _localPortsFormKey = GlobalKey<FormState>();
  final _remotePortsFormKey = GlobalKey<FormState>();

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

  Future<String> _sendNewPeerConfig() async {
    var payload = UpdateKnownPeerConfigRequest(
        _peerConfig.peerId, _aliasTextController.text, _peerConfig.allowedLocalPorts, _peerConfig.allowedRemotePorts);

    var response = await updateKnownPeerConfig(http.Client(), payload);
    return response;
  }

  void _addLocalPort() {
    var port = int.tryParse(_addNewLocalPortController.text);
    if (port == null) {
      return;
    }
    if (_peerConfig.allowedLocalPorts.containsKey(port)) {
      return;
    }
    _peerConfig.allowedLocalPorts[port] = LocalConnConfig(port, "");
    _addNewLocalPortController.text = "";
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_peerConfig == null) {
      _peerID = ModalRoute.of(context).settings.arguments;

      _refreshPeerConfig();
      return Container();
    }

    return Scaffold(
      key: _scaffoldKey,
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
            Center(child: Text('Local ports', style: Theme.of(context).textTheme.headline5)),
            _buildLocalPortsForm(),
            SizedBox(height: 15),
            Center(child: Text('Allowed remote ports', style: Theme.of(context).textTheme.headline5)),
            _buildRemotePortsForm(),
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
                      _scaffoldKey.currentState.showSnackBar(SnackBar(
                        backgroundColor: Colors.green,
                        content: Text("Successfully saved"),
                      ));
                    } else {
                      _scaffoldKey.currentState.showSnackBar(SnackBar(
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
        ],
      ),
    );
  }

  Widget _buildLocalPortsForm() {
    List<Widget> children = List();

    var ports = _peerConfig.allowedLocalPorts.keys.toList();
    ports.sort();

    for (int port in ports) {
      var cfg = _peerConfig.allowedLocalPorts[port];

      children.add(Row(
        children: [
          RawMaterialButton(
            elevation: 0.0,
            child: Icon(Icons.clear),
            constraints: BoxConstraints.tightFor(
              width: 30.0,
              height: 30.0,
            ),
            shape: CircleBorder(),
            onPressed: () {
              _peerConfig.allowedLocalPorts.remove(cfg.port);
              setState(() {});
            },
          ),
          Text(cfg.port.toString(), style: Theme.of(context).textTheme.headline6),
          Spacer(),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              child: TextFormField(
                initialValue: cfg.description,
                decoration: InputDecoration(labelText: 'Description'),
                maxLines: 4,
                minLines: 1,
                onChanged: (value) {
                  _peerConfig.allowedLocalPorts.update(port, (cfg) {
                    return LocalConnConfig(cfg.port, value);
                  });
                },
              ),
              width: 250,
            ),
          ),
        ],
      ));
    }

    children.add(Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          child: TextFormField(
            controller: _addNewLocalPortController,
            decoration: InputDecoration(labelText: 'Add new port'),
            autovalidate: true,
            validator: (String value) {
              if (value.isEmpty) {
                return null;
              }
              var port = int.tryParse(_addNewLocalPortController.text);
              if (port == null) {
                return "Only digits allowed";
              }

              return null;
            },
            maxLines: 1,
            minLines: 1,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (value) {
              _addLocalPort();
            },
          ),
          width: 150,
        ),
        RawMaterialButton(
          elevation: 0.0,
          child: Icon(Icons.add),
          constraints: BoxConstraints.tightFor(
            width: 40.0,
            height: 50.0,
          ),
          shape: CircleBorder(),
          onPressed: () {
            _addLocalPort();
          },
        ),
      ],
    ));

    return Form(
      key: _localPortsFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildRemotePortsForm() {
    List<Widget> children = List();

    var ports = _peerConfig.allowedRemotePorts.keys.toList();
    ports.sort();

    for (int port in ports) {
      var cfg = _peerConfig.allowedRemotePorts[port];

      if (cfg.description.isNotEmpty) {
        children.add(SizedBox(height: 12));
        children.add(Center(
          child:
              SelectableText(cfg.description, minLines: 1, maxLines: 3, style: Theme.of(context).textTheme.headline6),
        ));
      }

      children.add(Row(
        children: [
          Text("Remote ${cfg.remotePort}"),
          Icon(Icons.arrow_forward, size: 15),
          Text("local"),
          Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              child: TextFormField(
                initialValue: cfg.mappedLocalPort.toString(),
                decoration: InputDecoration(labelText: 'Port'),
                autovalidate: true,
                validator: (String value) {
                  if (value.isEmpty) {
                    return null;
                  }
                  var port = int.tryParse(value);
                  if (port == null) {
                    return "Only digits allowed";
                  }

                  return null;
                },
                onChanged: (value) {
                  var newPort = int.tryParse(value);
                  if (newPort == null) {
                    return;
                  }

                  _peerConfig.allowedRemotePorts.update(cfg.remotePort, (oldCfg) {
                    return RemoteConnConfig(oldCfg.remotePort, newPort, oldCfg.forwarded, oldCfg.description);
                  });
                },
                maxLines: 1,
                minLines: 1,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
              width: 80,
            ),
          ),
          Checkbox(
            value: cfg.forwarded,
            onChanged: (value) {
              _peerConfig.allowedRemotePorts.update(cfg.remotePort, (oldCfg) {
                return RemoteConnConfig(oldCfg.remotePort, oldCfg.mappedLocalPort, value, oldCfg.description);
              });
              setState(() {});
            },
          ),
          Text("Forward"),
        ],
      ));
    }

    return Form(
      key: _remotePortsFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

//  Widget _buildAddLocalPort() {
//  }

}
