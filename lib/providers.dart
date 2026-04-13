import 'dart:async';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Single shared [http.Client] for the lifetime of the app.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Single [ApiClient] that wraps [httpClientProvider]. All non-Riverpod
/// call sites (e.g. [NotificationsService]) receive this via constructor.
final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(httpClientProvider));
});

/// Global server-availability flag. Rehomed from the deleted
/// `data_service.dart`. Kept as a [ValueNotifier] so the existing
/// `ValueListenableBuilder<bool>` wraps in the `*Page` adapters work
/// unchanged. Polling notifiers update it via [_PollingAsyncNotifier].
final isServerAvailable = ValueNotifier<bool>(true);

/// Lifecycle switch. `active` while the app is in the foreground,
/// `paused` when backgrounded. Written from `didChangeAppLifecycleState`;
/// read by [_PollingAsyncNotifier] via `ref.watch` so flipping the state
/// rebuilds the notifier, which cancels or restarts its timer accordingly.
enum PollingPolicy { active, paused }

final pollingPolicyProvider = StateProvider<PollingPolicy>((_) => PollingPolicy.active);

/// Base class for the three backend polling notifiers. Performs an
/// initial fetch on build, then polls at a fixed 3s cadence while
/// [pollingPolicyProvider] is `active`. No backoff on failure: the
/// backend is always localhost and fast recovery is the priority.
abstract class _PollingAsyncNotifier<T> extends AsyncNotifier<T> {
  static const _interval = Duration(seconds: 3);
  Timer? _timer;

  Future<T> fetch();

  @override
  Future<T> build() async {
    ref.onDispose(_cancel);
    final policy = ref.watch(pollingPolicyProvider);
    _cancel();
    try {
      return await _guardedFetch();
    } finally {
      if (policy == PollingPolicy.active) {
        _timer = Timer.periodic(_interval, (_) => _tick());
      }
    }
  }

  Future<T> _guardedFetch() async {
    try {
      final value = await fetch();
      isServerAvailable.value = true;
      return value;
    } catch (_) {
      isServerAvailable.value = false;
      rethrow;
    }
  }

  Future<void> _tick() async {
    if (ref.read(pollingPolicyProvider) != PollingPolicy.active) return;
    state = await AsyncValue.guard(_guardedFetch);
  }

  /// Force a fresh read after a mutation. Does not reset timer cadence.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_guardedFetch);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

class MyPeerInfoNotifier extends _PollingAsyncNotifier<MyPeerInfo> {
  @override
  Future<MyPeerInfo> fetch() => ref.read(apiProvider).fetchMyPeerInfo();
}

final myPeerInfoProvider = AsyncNotifierProvider<MyPeerInfoNotifier, MyPeerInfo>(MyPeerInfoNotifier.new);

class KnownPeersNotifier extends _PollingAsyncNotifier<List<KnownPeer>?> {
  @override
  Future<List<KnownPeer>?> fetch() => ref.read(apiProvider).fetchKnownPeers();
}

final knownPeersProvider = AsyncNotifierProvider<KnownPeersNotifier, List<KnownPeer>?>(
  KnownPeersNotifier.new,
);

class AvailableProxiesNotifier extends _PollingAsyncNotifier<ListAvailableProxiesResponse?> {
  @override
  Future<ListAvailableProxiesResponse?> fetch() => ref.read(apiProvider).fetchAvailableProxies();
}

final availableProxiesProvider =
    AsyncNotifierProvider<AvailableProxiesNotifier, ListAvailableProxiesResponse?>(
      AvailableProxiesNotifier.new,
    );

/// Force-refresh all three providers. Throws if any fetch fails.
Future<void> refreshProviders(ProviderContainer container) => Future.wait([
  container.read(myPeerInfoProvider.notifier).refresh(),
  container.read(knownPeersProvider.notifier).refresh(),
  container.read(availableProxiesProvider.notifier).refresh(),
]);

/// Retry refreshing all three providers every 200ms until all succeed
/// (up to ~2s). Used after server start/restart to give the backend time
/// to warm up. Stops as soon as one full round succeeds.
Future<void> refreshProvidersRepeated(ProviderContainer container) async {
  await refreshProviders(container).catchError((_) {});
  for (var i = 0; i < 10; i++) {
    await Future.delayed(const Duration(milliseconds: 200));
    await refreshProviders(container).catchError((_) {});
  }
}
