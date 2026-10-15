import 'package:anywherelan/entities.dart';
import 'package:anywherelan/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/samples.dart';

/// Which notifications a poll of `auth_requests` shows and withdraws.
void main() {
  final alice = AuthRequest(samplePeerID, 'Alice', '10.66.0.2');
  final bob = AuthRequest(otherPeerID, 'Bob', '10.66.0.3');

  test('a request seen for the first time is shown', () {
    final diff = diffAuthRequests([], [alice]);
    expect(diff.added, [alice]);
    expect(diff.removed, isEmpty);
  });

  test('a request still pending is neither shown again nor withdrawn', () {
    final diff = diffAuthRequests([alice], [AuthRequest(samplePeerID, 'Alice', '10.66.0.2')]);
    expect(diff.added, isEmpty);
    expect(diff.removed, isEmpty);
  });

  test('a request that disappeared is withdrawn, by its peer ID', () {
    final diff = diffAuthRequests([alice, bob], [bob]);
    expect(diff.added, isEmpty);
    expect(diff.removed, [samplePeerID]);
  });

  test('an empty poll withdraws everything', () {
    final diff = diffAuthRequests([alice, bob], []);
    expect(diff.removed, unorderedEquals([samplePeerID, otherPeerID]));
  });

  test('one poll can both show and withdraw', () {
    final diff = diffAuthRequests([alice], [bob]);
    expect(diff.added, [bob]);
    expect(diff.removed, [samplePeerID]);
  });
}
