import 'dart:async';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/common.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MyInfoPage extends StatefulWidget {
  MyInfoPage({Key? key}) : super(key: key);

  @override
  _MyInfoPageState createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  MyPeerInfo? _peerInfo;
  bool _openedSetupDialog = false;

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

    final serverIsUp = _peerInfo!.uptime.inMicroseconds > 0;

    if (!_openedSetupDialog && serverIsUp && _peerInfo!.name.isEmpty) {
      _openedSetupDialog = true;
      Future.delayed(Duration(seconds: 2),
          () => showSettingsDialog(context, _peerInfo, true));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(children: _buildInfo(context)),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              icon: Icon(
                Icons.qr_code,
                color: Colors.black87,
              ),
              label: Text("SHOW ID"),
              onPressed: () async {
                myPeerInfoDataService.unsubscribe(_onNewPeerInfo);
                await showQRDialog(context, _peerInfo!.peerID, _peerInfo!.name);
                myPeerInfoDataService.subscribe(_onNewPeerInfo);
              },
            ),
            SizedBox(width: 14),
            OutlinedButton.icon(
              icon: Icon(
                Icons.settings,
                color: Colors.black87,
              ),
              label: Text("SETTINGS"),
              onPressed: () async {
                myPeerInfoDataService.unsubscribe(_onNewPeerInfo);
                await showSettingsDialog(context, _peerInfo, false);
                myPeerInfoDataService.subscribe(_onNewPeerInfo);
              },
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildInfo(BuildContext context) {
    var reachabilityText = "unknown";
    var reachabilityColor = unknownColor;
    switch (_peerInfo!.reachability) {
      case "Public":
        reachabilityText = "public address";
        reachabilityColor = greenColor;
        break;
      case "Private":
        reachabilityText = "private address";
        reachabilityColor = warnColor;
        break;
      default:
        reachabilityText = "unknown";
    }

    String dnsText;
    Color dnsColor;
    if (_peerInfo!.isAwlDNSSetAsSystem && _peerInfo!.awlDNSAddress != "") {
      dnsText = "working";
      dnsColor = greenColor;
    } else {
      dnsText = "not working";
      dnsColor = redColor;
    }

    String bootstrapText =
        "${_peerInfo!.connectedBootstrapPeers}/${_peerInfo!.totalBootstrapPeers}";
    Color bootstrapColor;
    if (_peerInfo!.connectedBootstrapPeers == 0) {
      bootstrapColor = redColor;
    } else if (_peerInfo!.connectedBootstrapPeers <=
        _peerInfo!.totalBootstrapPeers * 0.8) {
      bootstrapColor = warnColor;
    } else {
      bootstrapColor = greenColor;
    }

    return [
      _buildBodyItem(Icons.cloud_download_outlined, "Download rate ",
          _peerInfo!.networkStats.inAsString()),
      _buildBodyItem(Icons.cloud_upload_outlined, "Upload rate ",
          _peerInfo!.networkStats.outAsString()),
      _buildBodyItem(Icons.devices, "Bootstrap peers", bootstrapText,
          textColor: bootstrapColor),
      _buildBodyItem(Icons.dns_outlined, "DNS", dnsText, textColor: dnsColor),
      _buildBodyItem(Icons.my_location, "Reachability", reachabilityText,
          textColor: reachabilityColor),
      _buildBodyItem(
          Icons.access_time, "Uptime", formatDuration(_peerInfo!.uptime)),
      _buildBodyItem(
          Icons.label_outlined, "Server version ", _peerInfo!.serverVersion),
    ];
  }

  Widget _buildBodyItem(IconData icon, String label, String text,
      {Color? textColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon),
              SizedBox(width: 10),
              Text(label),
              SizedBox(width: 35),
            ],
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SelectableText(
              text,
              style: TextStyle(color: textColor),
            ),
          )
        ],
      ),
    );
  }
}

Future<void> showSettingsDialog(
    BuildContext context, MyPeerInfo? peerInfo, bool firstSetup) {
  return showDialog(
    context: context,
    barrierDismissible: !firstSetup,
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
  final MyPeerInfo? peerInfo;

  SettingsForm({Key? key, this.peerInfo}) : super(key: key);

  @override
  _SettingsFormState createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  TextEditingController? _peerNameTextController;
  final _formKey = GlobalKey<FormState>();

  String _serverError = "";

  void _onPressSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var response =
        await updateMySettings(http.Client(), _peerNameTextController!.text);
    if (response == "") {
      Navigator.pop(context);
      _serverError = "";
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green,
        content: Text("Successfully saved"),
      ));
    } else {
      _serverError = response;
      _formKey.currentState!.validate();
      _serverError = "";
    }
  }

  @override
  void initState() {
    super.initState();

    _peerNameTextController =
        TextEditingController(text: widget.peerInfo!.name);
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
          )
        ],
      ),
    );
  }
}
