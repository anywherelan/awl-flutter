import 'package:flutter/material.dart';
import 'package:peerlanflutter/api.dart';
import 'package:peerlanflutter/entities.dart';
import 'package:peerlanflutter/common.dart';
import 'package:peerlanflutter/data_service.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class MyInfoPage extends StatefulWidget {
  MyInfoPage({Key key}) : super(key: key);

  @override
  _MyInfoPageState createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  MyPeerInfo _peerInfo;

  void _onNewPeerInfo(MyPeerInfo newPeerInfo) async {
    if (!this.mounted) {
      return;
    }

    setState(() {
      _peerInfo = newPeerInfo;
    });
  }

  @override
  void initState() {
    super.initState();

    _peerInfo = myPeerInfoDataService.getData();
    myPeerInfoDataService.subscribe(_onNewPeerInfo);
    print("init MyInfoPage"); // REMOVE
  }

  @override
  void deactivate() {
    super.deactivate();
    // TODO: что делать в случае `In some cases, the framework will reinsert the State object into another part of the tree`
  }

  @override
  void dispose() {
    myPeerInfoDataService.unsubscribe(_onNewPeerInfo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_peerInfo == null) {
      return Container();
    }
    var displayName = _peerInfo.name != "" ? _peerInfo.name : "Unnamed";

    return ListView(
      children: [
        SizedBox(height: 16),
        Center(child: Text(displayName, style: Theme.of(context).textTheme.headline5)),
        SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child:
              ConstrainedBox(constraints: BoxConstraints(maxWidth: 620), child: Column(children: _buildInfo(context))),
        ),
        Padding(
          padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 10, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              RaisedButton.icon(
                icon: qrCodeImage,
                label: Text("Show ID"),
                onPressed: () async {
                  myPeerInfoDataService.unsubscribe(_onNewPeerInfo);
                  await showQRDialog(context, _peerInfo.peerID, _peerInfo.name);
                  myPeerInfoDataService.subscribe(_onNewPeerInfo);
                },
              ),
              SizedBox(width: 15),
              RaisedButton.icon(
                icon: Icon(Icons.settings),
                label: Text("Settings"),
                onPressed: () async {
                  myPeerInfoDataService.unsubscribe(_onNewPeerInfo);
                  await showSettingsDialog(context, _peerInfo);
                  myPeerInfoDataService.subscribe(_onNewPeerInfo);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInfo(BuildContext context) {
    return [
      _buildBodyItem(Icons.devices, "Peer ID", _peerInfo.peerID),
      _buildBodyItem(Icons.cloud_download, "Download rate ", _peerInfo.networkStats.inAsString()),
      _buildBodyItem(Icons.cloud_upload, "Upload rate ", _peerInfo.networkStats.outAsString()),
      _buildBodyItem(
          Icons.devices, "Bootstrap peers", "${_peerInfo.connectedBootstrapPeers}/${_peerInfo.totalBootstrapPeers}"),
      _buildBodyItem(Icons.access_time, "Uptime", formatDuration(_peerInfo.uptime)),
      _buildBodyItem(Icons.label, "Server version ", _peerInfo.serverVersion),
    ];
  }

  Widget _buildBodyItem(IconData icon, String label, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon),
              SizedBox(width: 10),
              Text(label),
              SizedBox(width: 65),
            ],
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SelectableText(text),
          )
        ],
      ),
    );
  }
}

Future<void> showSettingsDialog(BuildContext context, MyPeerInfo peerInfo) {
  return showDialog(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text("Settings"),
        children: [
          Center(
            child: SizedBox(
              width: 350,
              child: SettingsForm(peerInfo: peerInfo),
            ),
          ),
        ],
      );
    },
  );
}

class SettingsForm extends StatefulWidget {
  final MyPeerInfo peerInfo;

  SettingsForm({Key key, this.peerInfo}) : super(key: key);

  @override
  _SettingsFormState createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  TextEditingController _peerNameTextController;
  final _formKey = GlobalKey<FormState>();

  Future<String> _onPressSave() async {
    var response = await updateMySettings(http.Client(), _peerNameTextController.text);
    return response;
  }

  @override
  void initState() {
    super.initState();

    _peerNameTextController = TextEditingController(text: widget.peerInfo.name);
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
              decoration: InputDecoration(labelText: 'Name'),
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
            ),
          ),
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
                  var result = await _onPressSave();
//                  if (result == "") {
//                    Scaffold.of(context).showSnackBar(SnackBar(
//                      backgroundColor: Colors.green,
//                      content: Text("Successfully saved"),
//                    ));
//                  } else {
//                    Scaffold.of(context).showSnackBar(SnackBar(
//                      backgroundColor: Colors.red,
//                      content: Text(result),
//                    ));
//                  }
                  Navigator.pop(context);
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
