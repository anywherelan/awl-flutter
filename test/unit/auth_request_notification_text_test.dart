import 'package:anywherelan/entities.dart';
import 'package:anywherelan/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/samples.dart';

/// What a notification about an incoming friend request says.
void main() {
  test('a named request puts the name in the title and keeps the peer ID out', () {
    final text = authRequestNotificationText(AuthRequest(otherPeerID, 'Alice', ''), web: false);
    expect(text.title, 'Friend request from Alice');
    expect(text.body, 'Tap to accept or decline.');
    expect('${text.title} ${text.body}', isNot(contains(otherPeerID)));
  });

  test('a request without a name says so instead of leaving a gap', () {
    for (final name in ['', '  ']) {
      final text = authRequestNotificationText(AuthRequest(otherPeerID, name, ''), web: false);
      expect(text.title, 'Incoming friend request');
      expect(text.body, 'From an unnamed device. Tap to accept or decline.');
    }
  });

  test('the web overlay is clicked rather than tapped', () {
    final text = authRequestNotificationText(AuthRequest(otherPeerID, 'Alice', ''), web: true);
    expect(text.body, 'Click to accept or decline.');
  });
}
