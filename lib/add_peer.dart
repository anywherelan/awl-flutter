import 'dart:io';

import 'package:anywherelan/api.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

void showAddPeerDialog(BuildContext context) {
  showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text("Add new peer"),
        children: [
          Center(
            child: SizedBox(
              width: 450,
              child: AddPeerForm(),
            ),
          ),
        ],
      );
    },
  );
}

class AddPeerForm extends StatefulWidget {
  @override
  _AddPeerFormState createState() => _AddPeerFormState();
}

class _AddPeerFormState extends State<AddPeerForm> {
  final _peerIdTextController = TextEditingController();
  final _aliasTextController = TextEditingController();
  final _ipAddrTextController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _focusAlias = FocusNode();
  String _serverError = "";

  void _onPressInvite() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var response = await sendFriendRequest(
        http.Client(), _peerIdTextController.text, _aliasTextController.text, _ipAddrTextController.text);
    if (response == "") {
      // "Invitation was sent"
      _serverError = "";
      _formKey.currentState!.validate();
      Navigator.pop(context);
    } else {
      _serverError = response;
      _formKey.currentState!.validate();
      _serverError = "";
    }
  }

  void _scanQR(BuildContext context) async {
    if (kIsWeb) {
      // supported
    } else if (Platform.isAndroid) {
      var status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        return;
      }
    } else {
      return;
    }

    var res = await Navigator.of(context).push<Barcode>(MaterialPageRoute(builder: (BuildContext context) => QRScanPage()));
    if (res == null || res.displayValue == null || res.displayValue == '') {
      return;
    }

    setState(() {
      _peerIdTextController.text = res.displayValue!;
    });
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
              validator: (value) {
                if (value!.isEmpty) {
                  return 'Please enter peer id';
                } else if (_serverError != "") {
                  return _serverError;
                }
                return null;
              },
              controller: _peerIdTextController,
              decoration: InputDecoration(labelText: 'Peer ID'),
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (v) {
                FocusScope.of(context).requestFocus(_focusAlias);
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _aliasTextController,
              focusNode: _focusAlias,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value!.isEmpty) {
                  return 'Please enter peer name';
                }
                return null;
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _ipAddrTextController,
              decoration: InputDecoration(
                labelText: 'Local IP address',
                helperText: 'optional, example: 10.66.0.2',
              ),
              autovalidateMode: AutovalidateMode.onUnfocus,
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return null;
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
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton.icon(
                icon: Icon(
                  Icons.qr_code_scanner,
                  color: Colors.black87,
                ),
                label: Text('Scan QR'),
                onPressed: () async {
                  _scanQR(context);
                },
              ),
              ElevatedButton(
                child: Text('Invite peer'),
                onPressed: () async {
                  _onPressInvite();
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  Barcode? _barcode;

  void _handleBarcode(BarcodeCapture barcodes) {
    if (mounted && _barcode == null) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_barcode != null) {
      Navigator.of(context).pop(_barcode!);
      return Scaffold();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('PeerID QR Scanner')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleBarcode),
        ],
      ),
    );
  }
}
