import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';

/// Notifies about incoming friend requests: system notifications on Android,
/// overlays on web. What is shown follows `auth_requests`: a request that
/// disappears takes its notification with it, and everything goes when the
/// server becomes unavailable, since nothing can be answered without it.
class NotificationsService {
  /// Null on web, and on Android when the plugin failed to initialize: polling
  /// runs either way, there is just no system notification to show.
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  NotificationDetails? _notificationDetails;

  Timer? _timer;
  final _timerIntervalShort = const Duration(seconds: 3);
  final _timerIntervalLong = const Duration(seconds: 8);

  List<AuthRequest> _lastRequests = [];

  /// Web only: the overlay shown for each peer ID, so it can be withdrawn.
  final Map<String, OverlaySupportEntry> _overlays = {};

  final ApiClient _api;

  NotificationsService(this._api);

  Future<void> init() async {
    if (!kIsWeb) {
      await _initMobilePlugin();
    }
    isServerAvailable.addListener(_onServerAvailabilityChanged);

    // A lifecycle change may have started a timer while the plugin initialized.
    _timer?.cancel();
    _timer = Timer.periodic(_timerIntervalShort, (Timer t) => _checkForNotifications());
  }

  Future<void> _initMobilePlugin() async {
    final plugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid = AndroidInitializationSettings('app_icon');

    var initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    try {
      await plugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onSelectMobileNotification,
        // we don't use onBackground callback because when application starts we show request again
        // it's way easier than initialize application state here correctly. also it's not common case
      );
    } catch (e, s) {
      debugPrint('NotificationsService: failed to initialize notifications plugin: $e\n$s');
      return;
    }
    _notificationsPlugin = plugin;
    // Left over from a previous run and possibly stale; the first poll shows
    // again whatever is still pending.
    await _cancelAllMobile();

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'friend_requests',
      'Friend requests',
      channelDescription: 'Devices asking to join your network',
      importance: Importance.high,
      priority: Priority.high,
      // A tap opens the request; the notification goes once it is answered.
      autoCancel: false,
    );
    _notificationDetails = NotificationDetails(android: androidPlatformChannelSpecifics);

    // Not awaited: the answer may take as long as the user does.
    unawaited(
      plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission()
          .catchError((Object e) {
            debugPrint('NotificationsService: failed to request notifications permission: $e');
            return null;
          }),
    );
  }

  void close() async {
    _timer?.cancel();
    isServerAvailable.removeListener(_onServerAvailabilityChanged);
  }

  void setTimerIntervalShort() async {
    _timer?.cancel();
    _timer = Timer.periodic(_timerIntervalShort, (Timer t) => _checkForNotifications());
  }

  void setTimerIntervalLong() async {
    _timer?.cancel();
    _timer = Timer.periodic(_timerIntervalLong, (Timer t) => _checkForNotifications());
  }

  void _checkForNotifications() async {
    final List<AuthRequest> requests;
    try {
      requests = await _api.fetchAuthRequests();
    } catch (_) {
      // Not the same as an empty list: nothing is withdrawn on a failed poll.
      // A server that is really gone is handled by [_onServerAvailabilityChanged].
      return;
    }

    final diff = diffAuthRequests(_lastRequests, requests);
    _lastRequests = requests;

    for (final peerID in diff.removed) {
      await _withdraw(peerID);
    }
    for (final req in diff.added) {
      if (kIsWeb) {
        _showOverlayNotification(req);
      } else {
        await _showMobileNotification(req);
      }
    }
  }

  void _onServerAvailabilityChanged() {
    if (isServerAvailable.value) return;
    _lastRequests = [];
    for (final entry in _overlays.values.toList()) {
      entry.dismiss();
    }
    _overlays.clear();
    unawaited(_cancelAllMobile());
  }

  Future<void> _withdraw(String peerID) async {
    _overlays.remove(peerID)?.dismiss();

    final plugin = _notificationsPlugin;
    if (plugin == null) return;
    try {
      await plugin.cancel(generateNotificationId(peerID));
    } catch (e, s) {
      debugPrint('NotificationsService: failed to cancel notification: $e\n$s');
    }
  }

  Future<void> _cancelAllMobile() async {
    final plugin = _notificationsPlugin;
    if (plugin == null) return;
    try {
      await plugin.cancelAll();
    } catch (e, s) {
      debugPrint('NotificationsService: failed to cancel notifications: $e\n$s');
    }
  }

  Future<void> _showMobileNotification(AuthRequest req) async {
    final plugin = _notificationsPlugin;
    if (plugin == null) return;

    var notificationId = generateNotificationId(req.peerID);
    developer.log(
      'Showing auth request notification $notificationId for ${req.name}',
      name: 'NotificationsService',
    );

    final text = authRequestNotificationText(req, web: false);
    try {
      await plugin.show(notificationId, text.title, text.body, _notificationDetails, payload: req.peerID);
    } catch (e, s) {
      debugPrint('NotificationsService: failed to show notification: $e\n$s');
    }
  }

  void _showOverlayNotification(AuthRequest req) {
    final text = authRequestNotificationText(req, web: true);
    final entry = showOverlayNotification((context) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: SafeArea(
          child: ListTile(
            leading: SizedBox.fromSize(
              size: const Size(40, 40),
              child: ClipOval(child: Icon(Icons.devices)),
            ),
            title: Text(text.title),
            subtitle: Text(text.body),
            trailing: IconButton(icon: Icon(Icons.add), onPressed: () => _answer(req)),
            onTap: () => _answer(req),
          ),
        ),
      );
    }, duration: Duration(milliseconds: 0));

    // A second overlay would sit exactly on top of the first, and only one of
    // them could be withdrawn.
    final previous = _overlays[req.peerID];
    if (previous != null) {
      debugPrint('NotificationsService: overlay for ${req.peerID} shown twice, replacing the first');
      previous.dismiss();
    }
    _overlays[req.peerID] = entry;
  }

  /// Opens the request. Its notification stays until the request is answered
  /// or disappears from the server, so closing the dialog keeps it.
  Future<void> _answer(AuthRequest req) async {
    if (await _showAuthRequestDialog(req)) {
      // Without waiting up to a poll for the server to drop it.
      await _withdraw(req.peerID);
    }
  }

  void _onSelectMobileNotification(NotificationResponse notificationResponse) async {
    if (notificationResponse.payload == null) {
      return;
    }
    final payload = notificationResponse.payload!;
    var authReq = _lastRequests.firstWhere(
      (obj) => obj.peerID == payload,
      orElse: () => AuthRequest(payload, "", ""),
    );
    await _answer(authReq);
  }
}

/// True once the request was answered, false if the dialog was closed without.
Future<bool> _showAuthRequestDialog(AuthRequest req) async {
  final context = navigatorKey.currentContext;
  if (context == null) return false;
  final answered = await showDialog<bool>(
    context: context,
    builder: (context) => AuthRequestDialog(request: req),
  );
  return answered ?? false;
}

/// Adapter for [AuthRequestDialogView]: owns the API call. The pure
/// presentation logic lives in [AuthRequestDialogView].
class AuthRequestDialog extends ConsumerStatefulWidget {
  final AuthRequest request;

  const AuthRequestDialog({super.key, required this.request});

  @override
  ConsumerState<AuthRequestDialog> createState() => _AuthRequestDialogState();
}

class _AuthRequestDialogState extends ConsumerState<AuthRequestDialog> {
  Future<String> _onSubmit(FriendRequestReply reply) {
    return ref.read(apiProvider).replyFriendRequest(reply);
  }

  @override
  Widget build(BuildContext context) {
    return AuthRequestDialogView(
      request: widget.request,
      onSubmit: _onSubmit,
      onDone: () => Navigator.pop(context, true),
    );
  }
}

/// Pure presentation widget for an incoming friend request. Receives its data
/// and callbacks via constructor; never reads global services. Tests target
/// this widget directly.
class AuthRequestDialogView extends StatefulWidget {
  final AuthRequest request;

  /// Performs the reply; returns "" on success or the server error message.
  final Future<String> Function(FriendRequestReply) onSubmit;

  /// Called after a successful reply (the dialog closes itself this way).
  final VoidCallback? onDone;

  const AuthRequestDialogView({super.key, required this.request, required this.onSubmit, this.onDone});

  @override
  State<AuthRequestDialogView> createState() => _AuthRequestDialogViewState();
}

class _AuthRequestDialogViewState extends State<AuthRequestDialogView> {
  late TextEditingController _peerIdTextController;
  late TextEditingController _aliasTextController;
  late TextEditingController _ipAddrTextController;

  final _formKey = GlobalKey<FormState>();
  String? _serverError = "";
  bool _allowUsingAsExitNode = false;

  void _sendRequest(bool decline) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var response = await widget.onSubmit(
      FriendRequestReply(
        _peerIdTextController.text,
        _aliasTextController.text,
        decline,
        _ipAddrTextController.text,
        allowUsingAsExitNode: _allowUsingAsExitNode,
      ),
    );
    if (!mounted) return;
    if (response == "") {
      _serverError = "";
      _formKey.currentState!.validate();
      widget.onDone?.call();
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
  void dispose() {
    _peerIdTextController.dispose();
    _aliasTextController.dispose();
    _ipAddrTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: widget.request.name != ""
          ? Text("Incoming friend request from '${widget.request.name}'")
          : const Text("Incoming friend request"),
      content: SizedBox(width: 450, child: _buildForm(context)),
      actions: [
        TextButton(onPressed: () => _sendRequest(true), child: const Text('Decline')),
        FilledButton(onPressed: () => _sendRequest(false), child: const Text('Accept')),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
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
          SizedBox(height: 16),
          TextFormField(
            controller: _aliasTextController,
            decoration: InputDecoration(labelText: 'Name'),
          ),
          SizedBox(height: 16),
          TextFormField(
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
          SizedBox(height: 4),
          ExitNodePermissionField(
            value: _allowUsingAsExitNode,
            onChanged: (value) => setState(() => _allowUsingAsExitNode = value),
          ),
          SizedBox(height: 16),
          Text(
            "If you decline the invitation, the peer is added to Blocked peers and their requests "
            "are no longer shown. You can still add the peer yourself later if you want.",
          ),
        ],
      ),
    );
  }
}

/// What a notification about [req] says, on Android and in the web overlay
/// alike. No peer ID: it is in the dialog the notification opens, and in a
/// notification it only pushes the name out of sight.
({String title, String body}) authRequestNotificationText(AuthRequest req, {required bool web}) {
  final name = req.name.trim();
  final action = '${web ? 'Click' : 'Tap'} to accept or decline.';
  return name.isEmpty
      ? (title: 'Incoming friend request', body: 'From an unnamed device. $action')
      : (title: 'Friend request from $name', body: action);
}

/// Compares two polls of `auth_requests` by peer ID: [added] are the requests to
/// notify about, [removed] the peer IDs whose notifications have to go.
({List<AuthRequest> added, List<String> removed}) diffAuthRequests(
  List<AuthRequest> previous,
  List<AuthRequest> current,
) {
  final previousIDs = {for (final req in previous) req.peerID};
  final currentIDs = {for (final req in current) req.peerID};
  return (
    added: [
      for (final req in current)
        if (!previousIDs.contains(req.peerID)) req,
    ],
    removed: [
      for (final peerID in previousIDs)
        if (!currentIDs.contains(peerID)) peerID,
    ],
  );
}

int generateNotificationId(String id) {
  var content = Utf8Encoder().convert(id);
  var md5 = crypto.md5;
  var digest = md5.convert(content);

  var bdata = ByteData(4);
  bdata.setUint8(0, digest.bytes[0]);
  bdata.setUint8(1, digest.bytes[1]);
  bdata.setUint8(2, digest.bytes[2]);
  bdata.setUint8(3, digest.bytes[3]);

  return bdata.getInt32(0);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
