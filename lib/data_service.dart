import 'dart:async';
import 'dart:developer';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/entities.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

final isServerAvailable = ValueNotifier<bool>(true);

class ServerDataService<T> {
  Timer? _timer;
  final _timerDuration = const Duration(seconds: 3);
  bool _enabled = false;

  Future<T> Function() fetchDataFunc;

  T? _data;
  List<void Function(T)> _subscribers = [];

  ServerDataService(this.fetchDataFunc);

  void _deactivateTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void _updateTimer() {
    if (_timer == null && _enabled && _subscribers.isNotEmpty) {
      fetchData();
      _timer = new Timer.periodic(_timerDuration, _timerCallback);
    }
  }

  void _timerCallback(Timer t) {
    fetchData();
  }

  void enableTimer() {
    _enabled = true;
    _updateTimer();
  }

  void disableTimer() {
    _enabled = false;
    _deactivateTimer();
  }

  Future<void> fetchData() async {
    try {
      var newData = await fetchDataFunc();
      _data = newData;
      isServerAvailable.value = true;

      _subscribers.forEach((f) {
        f(newData);
      });
    } catch (e, s) {
      isServerAvailable.value = false;
      log(
        'Failed to fetch data',
        error: e,
        stackTrace: s,
        name: 'ServerDataService',
      );
    }
  }

  T? getData() {
    return _data;
  }

  void subscribe(void Function(T) callback) {
    _subscribers.add(callback);
    _updateTimer();
  }

  void unsubscribe(void Function(T) callback) {
    _subscribers.remove(callback);
    if (_subscribers.isEmpty) {
      _deactivateTimer();
    }
  }
}

var myPeerInfoDataService = ServerDataService<MyPeerInfo>(() {
  return fetchMyPeerInfo(http.Client());
});

var knownPeersDataService = ServerDataService<List<KnownPeer>?>(() {
  return fetchKnownPeers(http.Client());
});

var availableProxiesDataService = ServerDataService<ListAvailableProxiesResponse?>(() {
  return fetchAvailableProxies(http.Client());
});

Future<void> fetchAllData() async {
  var futures = <Future>[
    myPeerInfoDataService.fetchData(),
    knownPeersDataService.fetchData(),
    availableProxiesDataService.fetchData(),
  ];
  await Future.wait(futures);
}

Future<void> fetchAllDataAfterStart() async {
  await fetchAllData();
  for (var i = 0; i < 10; i++) {
    await Future.delayed(const Duration(milliseconds: 200));
    await fetchAllData();
  }
}
