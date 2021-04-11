import 'dart:async';
import 'package:anywherelan/api.dart';
import 'package:anywherelan/entities.dart';
import 'package:http/http.dart' as http;

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
    // TODO await ?
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
    // TODO try catch
    var newData = await fetchDataFunc();
    _data = newData;

    _subscribers.forEach((f) {
      f(newData);
    });
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
