import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone is on an unmetered network (Wi-Fi or Ethernet), for
/// the "Wi-Fi only" model download rule.
abstract interface class NetworkStatus {
  Future<bool> isUnmetered();

  /// Emits on every change, with the new value.
  Stream<bool> get unmeteredChanges;
}

class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _unmetered(List<ConnectivityResult> r) =>
      r.contains(ConnectivityResult.wifi) ||
      r.contains(ConnectivityResult.ethernet);

  @override
  Future<bool> isUnmetered() async =>
      _unmetered(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get unmeteredChanges =>
      _connectivity.onConnectivityChanged.map(_unmetered).distinct();
}
