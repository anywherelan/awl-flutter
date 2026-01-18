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

  Timer? _timer;
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
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onSelectMobileNotification,
        // we don't use onBackground callback because when application starts we show request again
        // it's way easier than initialize application state here correctly. also it's not common case
      );

      var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'friend_requests',
        'Friend requests',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );
      _notificationDetails = NotificationDetails(android: androidPlatformChannelSpecifics);

      _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _timer = new Timer.periodic(_timerIntervalShort, (Timer t) => _checkForNotifications());
  }

  void close() async {
    _timer?.cancel();
  }

  void setTimerIntervalShort() async {
    _timer?.cancel();
    _timer = new Timer.periodic(_timerIntervalShort, (Timer t) => _checkForNotifications());
  }

  void setTimerIntervalLong() async {
    _timer?.cancel();
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

  void _onSelectMobileNotification(NotificationResponse notificationResponse) async {
    if (notificationResponse.payload == null) {
      return;
    }
    final payload = notificationResponse.payload!;
    var authReq = _lastRequests.firstWhere((obj) => obj.peerID == payload, orElse: () => AuthRequest(payload, "", ""));
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
  late TextEditingController _peerIdTextController;
  late TextEditingController _aliasTextController;
  late TextEditingController _ipAddrTextController;

  final _formKey = GlobalKey<FormState>();
  String? _serverError = "";

  void _sendRequest(bool decline) async {
    var response =
    await replyFriendRequest(
        http.Client(), _peerIdTextController.text, _aliasTextController.text, decline, _ipAddrTextController.text);
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
    _aliasTextController = TextEditingController(text: widget.request.name);
    _ipAddrTextController = TextEditingController(text: widget.request.suggestedIP);
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
              minLines: 1,
              maxLines: 2,
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
              decoration: InputDecoration(labelText: 'Name'),
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
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  _sendRequest(true);
                },
              ),
              ElevatedButton(
                child: Text('ACCEPT'),
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
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
