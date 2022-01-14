import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/entities.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:overlay_support/overlay_support.dart';

class NotificationsService {
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  NotificationDetails? _notificationDetails;

  late Timer _timer;
  final _timerIntervalShort = const Duration(seconds: 3);
  final _timerIntervalLong = const Duration(seconds: 8);

  List<AuthRequest> _lastRequests = [];

  NotificationsService();

  void init() async {
    if (kIsWeb) {
      // nothing
    } else {
      _notificationsPlugin = FlutterLocalNotificationsPlugin();
      var initializationSettingsAndroid = AndroidInitializationSettings('app_icon');

      var initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await _notificationsPlugin.initialize(initializationSettings, onSelectNotification: _onSelectMobileNotification);

      var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'friend_requests',
        'Friend requests',
        '',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );
      _notificationDetails = NotificationDetails(android: androidPlatformChannelSpecifics);
    }

    _timer = new Timer.periodic(_timerIntervalShort, (Timer t) => _checkForNotifications());
  }

  void close() async {
    _timer.cancel();
  }

  void setTimerIntervalShort() async {
    _timer.cancel();
    _timer = new Timer.periodic(_timerIntervalShort, (Timer t) => _checkForNotifications());
  }

  void setTimerIntervalLong() async {
    _timer.cancel();
    _timer = new Timer.periodic(_timerIntervalLong, (Timer t) => _checkForNotifications());
  }

  void _checkForNotifications() async {
    var newRequests = await (fetchAuthRequests(http.Client()));
    if (newRequests.isEmpty) {
      _lastRequests = newRequests;
      return;
    }

    for (final req in newRequests) {
      if (_lastRequests.indexWhere((obj) => obj.peerID == req.peerID) != -1) {
        continue;
      }
      if (kIsWeb) {
        _showOverlayNotification(req);
      } else {
        await _showMobileNotification(req);
      }
    }

    _lastRequests = newRequests;
  }

  Future<void> _showMobileNotification(AuthRequest req) async {
    // TODO: проверять нет ли уже уведомления с payload с таким peerID - на случай если приложение перезапускалось,
    //  а уведомление еще висит

    var notificationId = generateNotificationId(req.peerID);
    print("$notificationId  ${req.name}");

    await _notificationsPlugin.show(
        notificationId, 'Incoming friend request', 'from ${req.name} with peerId ${req.peerID}', _notificationDetails,
        payload: req.peerID);
  }

  Future<void> _showOverlayNotification(AuthRequest req) async {
    showOverlayNotification((context) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: SafeArea(
          child: ListTile(
            leading: SizedBox.fromSize(
              size: const Size(40, 40),
              child: ClipOval(
                child: Icon(Icons.devices),
              ),
            ),
            title: Text('Incoming friend request'),
            subtitle: req.name == ""
                ? Text("from PeerID ${req.peerID}")
                : Text("from '${req.name}' with peerId ${req.peerID}"),
            trailing: IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  OverlaySupportEntry.of(context)!.dismiss();
                  _showAuthRequestDialog(req);
                }),
            onTap: () {
              OverlaySupportEntry.of(context)!.dismiss();
              _showAuthRequestDialog(req);
            },
          ),
        ),
      );
    }, duration: Duration(milliseconds: 0));
  }

  Future _onSelectMobileNotification(String? payload) async {
    if (payload == null) {
      return;
    }
    var authReq = _lastRequests.firstWhere((obj) => obj.peerID == payload, orElse: () => AuthRequest(payload, ""));
    _showAuthRequestDialog(authReq);
  }
}

Future _showAuthRequestDialog(AuthRequest req) async {
  if (navigatorKey.currentContext == null) return;
  showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) {
      return SimpleDialog(
        title: req.name != "" ? Text("Incoming friend request from '${req.name}'") : Text("Incoming friend request"),
        children: [
          Center(
            child: SizedBox(
              width: 450,
              child: IncomingAuthRequestForm(request: req),
            ),
          ),
        ],
      );
    },
  );
}

class IncomingAuthRequestForm extends StatefulWidget {
  final AuthRequest request;

  IncomingAuthRequestForm({Key? key, required this.request}) : super(key: key);

  @override
  _IncomingAuthRequestFormState createState() => _IncomingAuthRequestFormState();
}

class _IncomingAuthRequestFormState extends State<IncomingAuthRequestForm> {
  TextEditingController? _peerIdTextController;
  final _aliasTextController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String? _serverError = "";

  void _sendRequest(bool decline) async {
    var response =
        await replyFriendRequest(http.Client(), _peerIdTextController!.text, _aliasTextController.text, decline);
    if (response == "") {
      Navigator.pop(context);
      _serverError = "";
      _formKey.currentState!.validate();
    } else {
      _serverError = "server error: $response";
      _formKey.currentState!.validate();
      _serverError = "";
    }
  }

  @override
  void initState() {
    super.initState();

    _peerIdTextController = TextEditingController(text: widget.request.peerID);
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
              controller: _peerIdTextController,
              decoration: InputDecoration(labelText: 'Peer ID'),
              readOnly: true,
              validator: (value) {
                if (_serverError != "") {
                  return _serverError;
                }
                return null;
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _aliasTextController,
              decoration: InputDecoration(hintText: 'Alias'),
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
                "If you decline the invitation, it will no longer be shown. You can still add the peer yourself later if you want."),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton(
                child: Text('DECLINE'),
                onPressed: () async {
                  _sendRequest(true);
                },
              ),
              ElevatedButton(
                child: Text('ACCEPT'),
                onPressed: () async {
                  _sendRequest(false);
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}

int generateNotificationId(String id) {
  var content = new Utf8Encoder().convert(id);
  var md5 = crypto.md5;
  var digest = md5.convert(content);

  // TODO: try
//  return getCrc32(digest.bytes);

  var bdata = new ByteData(4);
  bdata.setUint8(0, digest.bytes[0]);
  bdata.setUint8(1, digest.bytes[1]);
  bdata.setUint8(2, digest.bytes[2]);
  bdata.setUint8(3, digest.bytes[3]);

  return bdata.getInt32(0);
}

final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
