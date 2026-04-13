import 'dart:io';

import 'package:anywherelan/providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:permission_handler/permission_handler.dart';

void showAddPeerDialog(BuildContext context) {
  showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text("Add new peer"),
        children: [Center(child: SizedBox(width: 450, child: AddPeerForm()))],
      );
    },
  );
}

class AddPeerForm extends ConsumerStatefulWidget {
  const AddPeerForm({super.key});

  @override
  ConsumerState<AddPeerForm> createState() => _AddPeerFormState();
}

class _AddPeerFormState extends ConsumerState<AddPeerForm> {
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

    var response = await ref
        .read(apiProvider)
        .sendFriendRequest(_peerIdTextController.text, _aliasTextController.text, _ipAddrTextController.text);
    if (!mounted) return;
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
    if (Platform.isAndroid) {
      var status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        return;
      }
    } else {
      return;
    }
    if (!context.mounted) return;

    var res = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (BuildContext context) => QRScanPage()));
    if (res == null || res.isEmpty) {
      return;
    }

    setState(() {
      _peerIdTextController.text = res;
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
              if (!kIsWeb)
                OutlinedButton.icon(
                  icon: Icon(Icons.qr_code_scanner),
                  label: Text('Scan QR'),
                  onPressed: () async {
                    _scanQR(context);
                  },
                ),
              FilledButton.icon(
                icon: Icon(Icons.send, size: 18),
                label: Text('Invite peer'),
                onPressed: () async {
                  _onPressInvite();
                },
              ),
            ],
          ),
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
  String? _result;

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      Navigator.of(context).pop(_result);
      return const Scaffold();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('PeerID QR Scanner')),
      backgroundColor: Colors.black,
      body: ReaderWidget(
        cropPercent: 0.9,
        onScan: (Code code) {
          if (_result == null && code.isValid && (code.text ?? '').isNotEmpty) {
            setState(() => _result = code.text);
          }
        },
      ),
    );
  }
}
