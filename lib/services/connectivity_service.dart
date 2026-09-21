import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'pos_database.dart';

/// Sync state machine transitions
enum SyncState {
  idle,
  syncing,
  error,
}

/// Central connectivity and sync state coordinator.
/// Verifies real IP-level internet reachability using `connectivity_plus` + `internet_connection_checker_plus`,
/// debounces transient network flickers, coordinates FIFO queue flushing, and notifies UI observers.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  Connectivity _connectivity = Connectivity();
  InternetConnection _internetConnection = InternetConnection();

  StreamSubscription<dynamic>? _connectivitySubscription;
  StreamSubscription<InternetStatus>? _internetStatusSubscription;
  Timer? _debounceTimer;

  bool _isOnline = true;
  bool _initialized = false;
  SyncState _syncState = SyncState.idle;
  int _pendingCount = 0;
  String? _lastSyncError;
  DateTime? _lastSyncedAt;

  // Sync flush callback hook (injected from SyncService)
  Future<void> Function()? _onFlushQueue;

  // Testing overrides
  @visibleForTesting
  bool? testOnlineOverride;
  @visibleForTesting
  Future<bool> Function()? testReachabilityChecker;

  @visibleForTesting
  void resetForTesting({bool online = true}) {
    _isOnline = online;
    _syncState = SyncState.idle;
    _pendingCount = 0;
    _lastSyncError = null;
    _lastSyncedAt = null;
    testOnlineOverride = null;
    testReachabilityChecker = null;
    _onFlushQueue = null;
  }

  bool get isOnline => testOnlineOverride ?? _isOnline;
  SyncState get syncState => _syncState;
  int get pendingCount => _pendingCount;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasPendingMutations => _pendingCount > 0;

  final StreamController<bool> _onlineStreamController =
      StreamController<bool>.broadcast();
  Stream<bool> get isOnlineStream => _onlineStreamController.stream;

  /// Registers sync engine flush handler
  void registerSyncEngine(Future<void> Function() onFlush) {
    _onFlushQueue = onFlush;
  }

  /// Initialize connectivity listeners with IP-level verification
  Future<void> initialize({
    Connectivity? connectivity,
    InternetConnection? internetConnection,
  }) async {
    if (_initialized) return;

    if (connectivity != null) _connectivity = connectivity;
    if (internetConnection != null) _internetConnection = internetConnection;

    _initialized = true;

    // Initial check
    await checkReachability(immediate: true);
    await refreshPendingCount();

    // Listen to OS network interface changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _debounceConnectivityCheck(result);
    });

    // Listen to real IP reachability transitions when supported
    try {
      _internetStatusSubscription = _internetConnection.onStatusChange.listen((status) {
        final online = status == InternetStatus.connected;
        _updateOnlineState(online);
      });
    } catch (e) {
      debugPrint('ConnectivityService: InternetConnection listener notice: $e');
    }
  }

  /// Debounce rapid hardware changes (750ms) to prevent UI jitter
  void _debounceConnectivityCheck(dynamic result) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 750), () async {
      final hasInterface = _hasNetworkInterface(result);
      if (!hasInterface) {
        _updateOnlineState(false);
      } else {
        await checkReachability();
      }
    });
  }

  bool _hasNetworkInterface(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.isNotEmpty && !result.every((r) => r == ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return false;
  }

  /// Check actual IP-level data reachability
  Future<bool> checkReachability({bool immediate = false}) async {
    if (testOnlineOverride != null) {
      _updateOnlineState(testOnlineOverride!);
      return testOnlineOverride!;
    }

    if (testReachabilityChecker != null) {
      final reachable = await testReachabilityChecker!();
      _updateOnlineState(reachable);
      return reachable;
    }

    try {
      // 1. Verify network interface
      final connectivityResult = await _connectivity.checkConnectivity();
      if (!_hasNetworkInterface(connectivityResult)) {
        _updateOnlineState(false);
        return false;
      }

      // 2. Verify real IP reachability (ping/dns/http access)
      final reachable = await _internetConnection.hasInternetAccess;
      _updateOnlineState(reachable);
      return reachable;
    } catch (e) {
      debugPrint('ConnectivityService: Reachability check error ($e). Assuming offline.');
      _updateOnlineState(false);
      return false;
    }
  }

  /// Update online state, notify stream and listeners, and trigger auto-flush if returning online
  void _updateOnlineState(bool online) {
    final wasOffline = !_isOnline;
    final changed = _isOnline != online;
    _isOnline = online;

    if (changed) {
      _onlineStreamController.add(online);
      notifyListeners();
    }

    // Auto-flush queue on transition: offline -> online
    if (wasOffline && online) {
      debugPrint('ConnectivityService: Internet restored! Auto-flushing pending sync queue...');
      triggerFlush();
    }
  }

  /// Trigger background flush if online
  void triggerFlush() {
    if (!isOnline) return;
    final flushHandler = _onFlushQueue;
    if (flushHandler != null) {
      unawaited(flushHandler());
    }
  }

  /// Manual retry tap action from UI status banner
  Future<void> retrySync() async {
    final online = await checkReachability(immediate: true);
    if (online) {
      final flushHandler = _onFlushQueue;
      if (flushHandler != null) {
        await flushHandler();
      }
    } else {
      setSyncState(SyncState.error, error: 'Cannot reach internet. Check connection.');
    }
  }

  /// Update current sync state
  void setSyncState(SyncState state, {String? error}) {
    _syncState = state;
    _lastSyncError = error;
    if (state == SyncState.idle && error == null) {
      _lastSyncedAt = DateTime.now();
    }
    notifyListeners();
  }

  /// Refresh count of pending items from PosDatabase
  Future<void> refreshPendingCount() async {
    try {
      final count = await PosDatabase.instance.getPendingQueueCount();
      if (_pendingCount != count) {
        _pendingCount = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ConnectivityService.refreshPendingCount notice: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    _internetStatusSubscription?.cancel();
    _onlineStreamController.close();
    super.dispose();
  }
}
