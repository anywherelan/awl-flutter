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
      Future.delayed(Duration(seconds: 2), () => showSettingsDialog(context, _peerInfo, true));
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
              icon: Icon(Icons.qr_code, color: Colors.black87),
              label: Text("SHOW MY ID"),
              onPressed: () async {
                myPeerInfoDataService.unsubscribe(_onNewPeerInfo);
                await showQRDialog(context, _peerInfo!.peerID, _peerInfo!.name);
                myPeerInfoDataService.subscribe(_onNewPeerInfo);
              },
            ),
            SizedBox(width: 14),
            OutlinedButton.icon(
              icon: Icon(Icons.settings, color: Colors.black87),
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

    String socks5Text;
    Color socks5Color;
    if (_peerInfo!.socks5.listenerEnabled && _peerInfo!.socks5.listenAddress != "") {
      socks5Text = "working";
      socks5Color = greenColor;
    } else {
      socks5Text = "not working";
      socks5Color = redColor;
    }

    String bootstrapText = "${_peerInfo!.connectedBootstrapPeers}/${_peerInfo!.totalBootstrapPeers}";
    Color bootstrapColor;
    if (_peerInfo!.connectedBootstrapPeers == 0) {
      bootstrapColor = redColor;
    } else if (_peerInfo!.connectedBootstrapPeers <= _peerInfo!.totalBootstrapPeers * 0.8) {
      bootstrapColor = warnColor;
    } else {
      bootstrapColor = greenColor;
    }

    return [
      // TODO: organize output in sections: general, vpn, proxy, etc
      _buildBodyItemText(Icons.cloud_download_outlined, "Download rate ", _peerInfo!.networkStats.inAsString()),
      _buildBodyItemText(Icons.cloud_upload_outlined, "Upload rate ", _peerInfo!.networkStats.outAsString()),
      _buildBodyItemText(Icons.devices, "Bootstrap peers", bootstrapText, textColor: bootstrapColor),
      _buildBodyItemText(Icons.dns_outlined, "DNS", dnsText, textColor: dnsColor),

      _buildBodyItemText(Icons.router_outlined, "SOCKS5 Proxy", socks5Text, textColor: socks5Color),
      if (_peerInfo!.socks5.listenerEnabled)
        _buildBodyItemText(Icons.router_outlined, "SOCKS5 Proxy address", "${_peerInfo!.socks5.listenAddress}"),
      _buildProxySelectorWidget("SOCKS5 Proxy exit peer"),

      _buildBodyItemText(Icons.my_location, "Reachability", reachabilityText, textColor: reachabilityColor),
      _buildBodyItemText(Icons.access_time, "Uptime", formatDuration(_peerInfo!.uptime)),
      _buildBodyItemText(Icons.label_outlined, "Server version ", _peerInfo!.serverVersion),
    ];
  }

  Widget _buildBodyItemText(IconData icon, String label, String text, {Color? textColor}) {
    return _buildBodyItemWidget(icon, label, SelectableText(text, style: TextStyle(color: textColor)));
  }

  Widget _buildBodyItemWidget(IconData icon, String label, Widget child) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon), SizedBox(width: 10), Text(label), SizedBox(width: 35)]),
          Flexible(fit: FlexFit.loose, child: child),
        ],
      ),
    );
  }

  Widget _buildProxySelectorWidget(String label) {
    var socks5UsingPeer = _peerInfo!.socks5.usingPeerName;
    if (socks5UsingPeer == "") {
      socks5UsingPeer = "None";
    }

    List<String> socks5PeersList = <String>['None'];
    var proxiesData = availableProxiesDataService.getData();
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
      Icons.router_outlined,
      label,
      DropdownButton<String>(
        value: socks5UsingPeer,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (String? value) async {
          var usingPeerName = value ?? "";
          var usingPeerID = "";
          if (usingPeerName == "None") {
            usingPeerID = "";
          } else {
            var proxiesData = availableProxiesDataService.getData();

            var found = proxiesData!.proxies.firstWhere((element) => element.peerName == usingPeerName);
            usingPeerID = found.peerID;
          }

          var response = await updateProxySettings(http.Client(), usingPeerID);
          if (response != "") {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Failed to update proxy settings: $response")));

            return;
          }

          var futures = <Future>[myPeerInfoDataService.fetchData(), availableProxiesDataService.fetchData()];
          await Future.wait(futures);

          setState(() {
            // to trigger rebuild after fetching
          });
        },
        onTap: () {
          availableProxiesDataService.fetchData();
        },
        items: socks5PeersList.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
            alignment: AlignmentDirectional.centerEnd,
          );
        }).toList(),
      ),
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

    var response = await updateMySettings(http.Client(), _peerNameTextController!.text);
    if (response == "") {
      Navigator.pop(context);
      _serverError = "";
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text("Successfully saved")));
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
