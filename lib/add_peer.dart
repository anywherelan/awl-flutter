import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:peerlanflutter/api.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  final _formKey = GlobalKey<FormState>();
  final _focusAlias = FocusNode();
  String _serverError = "";

  void _onPressInvite() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var response = await sendFriendRequest(http.Client(), _peerIdTextController.text, _aliasTextController.text);
    if (response == "") {
      // "Invitation was sent"
      Navigator.pop(context);
      _serverError = "";
      _formKey.currentState!.validate();
    } else {
      _serverError = response;
      _formKey.currentState!.validate();
      _serverError = "";
    }
  }

  void _scanQR() async {
    // TODO: support web; there is an open PR in lib
    if (Platform.isAndroid) {
      var status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        return;
      }
    } else {
      return;
    }

    // TODO: reimplement with qr_code_scanner lib
    // var result = await BarcodeScanner.scan();
    // if (result.type == ResultType.Barcode && result.rawContent != "") {
    //   setState(() {
    //     _peerIdTextController.text = result.rawContent;
    //   });
    // }
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
                  return 'Please enter some text';
                } else if (_serverError != "") {
                  return _serverError;
                }
                return null;
              },
              controller: _peerIdTextController,
              decoration: InputDecoration(hintText: 'Peer ID'),
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
              decoration: InputDecoration(hintText: 'Alias'),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              if (!kIsWeb)
                RaisedButton.icon(
                  icon: Image(image: AssetImage('assets/qrcode.png')),
                  label: Text('Scan QR'),
                  onPressed: () async {
                    _scanQR();
                  },
                ),
              RaisedButton(
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
