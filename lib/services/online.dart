import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has a network connection.
/// Firestore queues writes while offline and their futures never settle, which would leave
/// buttons spinning, so writes check this first and fail straight away instead.
class Online extends ChangeNotifier {
  Online._() {
    Connectivity().checkConnectivity().then(_update, onError: (_) {});
    _sub = Connectivity().onConnectivityChanged.listen(_update, onError: (_) {});
  }
  static final Online instance = Online._();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;
  bool get isOnline => _online;

  void _update(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next != _online) {
      _online = next;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
