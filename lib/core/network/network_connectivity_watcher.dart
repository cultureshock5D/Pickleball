import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstract contract for observing network connectivity state changes.
abstract class NetworkConnectivityWatcher {
  /// Stream emitting connectivity status (true = connected, false = disconnected).
  Stream<bool> get onConnectivityChanged;

  /// Returns true if currently connected to a network interface.
  Future<bool> get isConnected;

  /// Cleans up active listeners and controllers.
  void dispose();
}

/// Production implementation of [NetworkConnectivityWatcher] using `package:connectivity_plus`.
class DefaultNetworkConnectivityWatcher implements NetworkConnectivityWatcher {
  final Connectivity _connectivity;
  StreamController<bool>? _controller;
  StreamSubscription<dynamic>? _subscription;

  DefaultNetworkConnectivityWatcher({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Normalizes connectivity results across both v5 (`ConnectivityResult`) and v6 (`List<ConnectivityResult>`).
  static bool isOnlineResult(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.isNotEmpty && !result.every((r) => r == ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return false;
  }

  @override
  Stream<bool> get onConnectivityChanged {
    _controller ??= StreamController<bool>.broadcast(
      onListen: () {
        _subscription = _connectivity.onConnectivityChanged.listen((result) {
          _controller?.add(isOnlineResult(result));
        });
      },
      onCancel: () {
        _subscription?.cancel();
        _subscription = null;
      },
    );
    return _controller!.stream;
  }

  @override
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return isOnlineResult(result);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller?.close();
    _controller = null;
  }
}

/// Fake implementation of [NetworkConnectivityWatcher] powered by a pure Dart [StreamController].
/// Used for deterministic unit, widget, and integration testing without platform channels.
class FakeNetworkConnectivityWatcher implements NetworkConnectivityWatcher {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _currentStatus;

  FakeNetworkConnectivityWatcher({bool initialConnected = true})
      : _currentStatus = initialConnected;

  /// Manually changes connectivity state and broadcasts to active listeners.
  void setConnected(bool connected) {
    _currentStatus = connected;
    _controller.add(connected);
  }

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isConnected async => _currentStatus;

  @override
  void dispose() {
    _controller.close();
  }
}
