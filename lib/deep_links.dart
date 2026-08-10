import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Delivers `awl://` links opened outside the app (a tap in a messenger, a
/// system QR scanner) to whoever wants to act on them — in practice the
/// add-peer form, prefilled with an invite link.
///
/// **Android only.** There the custom scheme is the main way in: the app is
/// the only UI. On web the UI runs in a
/// browser at 127.0.0.1, which a custom scheme never reaches; on desktop,
/// registering the scheme is per-OS work (`.desktop` + `xdg-mime`, registry
/// keys, `Info.plist`) that would have to hand the link to the tray app. Both
/// paste the link into the form instead, so this service is a no-op there.
class DeepLinkService {
  /// Called for every incoming link, including the one the app was launched
  /// with (`uriLinkStream` replays it to its first listener).
  final void Function(Uri) onLink;

  StreamSubscription<Uri>? _subscription;

  DeepLinkService(this.onLink);

  void init() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _subscription = AppLinks().uriLinkStream.listen(
      onLink,
      onError: (Object e, StackTrace s) {
        // A malformed link is the user's problem, not a crash: the form shows
        // what is wrong with it. Anything reaching here is a plugin-level
        // failure, so it is only worth a log line.
        developer.log('Failed to receive a deep link', error: e, stackTrace: s, name: 'DeepLinkService');
      },
    );
  }

  void close() {
    _subscription?.cancel();
    _subscription = null;
  }
}
