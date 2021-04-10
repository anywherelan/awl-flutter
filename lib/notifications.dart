import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:peerlanflutter/api.dart';
import 'package:peerlanflutter/entities.dart';
import 'package:overlay_support/overlay_support.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:typed_data';

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

      // TODO
      var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'channel id', 'channel name', 'channel description',
        importance: Importance.high, priority: Priority.high, ticker: 'ticker',
//      onlyAlertOnce: true // TODO
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
  showDialog(
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
  IncomingAuthRequestForm({Key? key, this.request}) : super(key: key);

  final AuthRequest? request;

  @override
  _IncomingAuthRequestFormState createState() => _IncomingAuthRequestFormState();
}

class _IncomingAuthRequestFormState extends State<IncomingAuthRequestForm> {
  TextEditingController? _peerIdTextController;
  final _aliasTextController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String? _serverError = "";

  void _onPressAddPeer() async {
    var response = await acceptFriendRequest(http.Client(), _peerIdTextController!.text, _aliasTextController.text);
    if (response == "") {
      Navigator.pop(context);
      _serverError = "";
      _formKey.currentState!.validate();
    } else {
      _serverError = response;
      _formKey.currentState!.validate();
      _serverError = "";
    }
  }

  @override
  void initState() {
    super.initState();

    _peerIdTextController = TextEditingController(text: widget.request!.peerID);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              RaisedButton(
                child: Text('Ignore'),
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
              RaisedButton(
                child: Text('Accept'),
                onPressed: () async {
                  _onPressAddPeer();
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
ThemeData? globalTheme;

// TODO: придумать способ без этого хака

// copied from flutter to avoid passing BuildContext
Future<T?> showDialog<T>({
  WidgetBuilder? builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  @Deprecated('Instead of using the "child" argument, return the child from a closure '
      'provided to the "builder" argument. This will ensure that the BuildContext '
      'is appropriate for widgets built in the dialog. '
      'This feature was deprecated after v0.2.3.')
      Widget? child,
}) {
  assert(child == null || builder == null);
  assert(barrierDismissible != null);
  assert(useSafeArea != null);
  assert(useRootNavigator != null);

  final ThemeData? theme = globalTheme;
  return showGeneralDialog(
    pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
      final Widget pageChild = child ?? Builder(builder: builder!);
      Widget dialog = Builder(builder: (BuildContext context) {
        return theme != null ? Theme(data: theme, child: pageChild) : pageChild;
      });
      if (useSafeArea) {
        dialog = SafeArea(child: dialog);
      }
      return dialog;
    },
    barrierDismissible: barrierDismissible,
    barrierLabel: "",
    // TODO
    barrierColor: barrierColor ?? Colors.black54,
    transitionDuration: const Duration(milliseconds: 150),
    transitionBuilder: _buildMaterialDialogTransitions,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  );
}

Widget _buildMaterialDialogTransitions(
    BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
  return FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ),
    child: child,
  );
}

Future<T?> showGeneralDialog<T>({
  required RoutePageBuilder pageBuilder,
  required bool barrierDismissible,
  String? barrierLabel,
  Color? barrierColor,
  Duration? transitionDuration,
  RouteTransitionsBuilder? transitionBuilder,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  assert(pageBuilder != null);
  assert(useRootNavigator != null);
  assert(!barrierDismissible || barrierLabel != null);
  return navigatorKey.currentState!.push<T>(_DialogRoute<T>(
    pageBuilder: pageBuilder,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: barrierColor,
    transitionDuration: transitionDuration,
    transitionBuilder: transitionBuilder,
    settings: routeSettings,
  ));
}

class _DialogRoute<T> extends PopupRoute<T> {
  _DialogRoute({
    required RoutePageBuilder pageBuilder,
    bool barrierDismissible = true,
    String? barrierLabel,
    Color? barrierColor = const Color(0x80000000),
    Duration? transitionDuration = const Duration(milliseconds: 200),
    RouteTransitionsBuilder? transitionBuilder,
    RouteSettings? settings,
  })  : assert(barrierDismissible != null),
        _pageBuilder = pageBuilder,
        _barrierDismissible = barrierDismissible,
        _barrierLabel = barrierLabel,
        _barrierColor = barrierColor,
        _transitionDuration = transitionDuration,
        _transitionBuilder = transitionBuilder,
        super(settings: settings);

  final RoutePageBuilder _pageBuilder;

  @override
  bool get barrierDismissible => _barrierDismissible;
  final bool _barrierDismissible;

  @override
  String? get barrierLabel => _barrierLabel;
  final String? _barrierLabel;

  @override
  Color? get barrierColor => _barrierColor;
  final Color? _barrierColor;

  @override
  Duration get transitionDuration => _transitionDuration!;
  final Duration? _transitionDuration;

  final RouteTransitionsBuilder? _transitionBuilder;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Semantics(
      child: _pageBuilder(context, animation, secondaryAnimation),
      scopesRoute: true,
      explicitChildNodes: true,
    );
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_transitionBuilder == null) {
      return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.linear,
          ),
          child: child);
    } // Some default transition
    return _transitionBuilder!(context, animation, secondaryAnimation, child);
  }
}
