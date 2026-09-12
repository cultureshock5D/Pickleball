import 'dart:async';
import 'package:flutter/widgets.dart';

import '../network/network_connectivity_watcher.dart';
import '../network/network_resilience.dart';
import 'keyset_cursor.dart';
import 'pagination_state.dart';

/// Type signature for fetching a paginated chunk of items.
typedef ChunkFetcher<T> = Future<PageChunk<T>> Function(
  KeysetCursor? cursor,
  int pageSize,
);

/// Controller managing keyset cursor pagination state transitions, deduplication,
/// network resilience, scroll prefetching, and offline auto-resume.
class PaginationController<T> extends ChangeNotifier {
  final ChunkFetcher<T> _fetchPageChunk;
  final String Function(T item) _idExtractor;
  final int pageSize;
  final NetworkConnectivityWatcher? _connectivityWatcher;

  PaginationState<T> _state = PaginationInitialLoading<T>();
  KeysetCursor? _currentCursor;
  final Set<String> _seenIds = <String>{};

  bool _isFetching = false;
  int _currentEpoch = 0;
  bool _wasOffline = false;
  bool _isDisposed = false;

  StreamSubscription<bool>? _connectivitySubscription;
  ScrollController? _attachedScrollController;
  double _prefetchThreshold = 500.0;
  VoidCallback? _scrollListener;

  PaginationController({
    required ChunkFetcher<T> fetchPageChunk,
    required String Function(T item) idExtractor,
    this.pageSize = 15,
    NetworkConnectivityWatcher? connectivityWatcher,
    bool autoLoad = true,
  })  : _fetchPageChunk = fetchPageChunk,
        _idExtractor = idExtractor,
        _connectivityWatcher = connectivityWatcher {
    _initConnectivityWatcher();
    if (autoLoad) {
      initialLoad();
    }
  }

  /// Current pagination state.
  PaginationState<T> get state => _state;

  /// True if this controller has been disposed.
  bool get isDisposed => _isDisposed;

  /// Loaded items for the current state.
  List<T> get items => _state.currentItems;

  /// Next cursor to continue pagination from, or null if exhausted.
  KeysetCursor? get currentCursor => _currentCursor;

  /// True if a network or data query is actively in flight.
  bool get isFetching => _isFetching;

  /// Sets up offline/online transition listening to auto-resume chunk fetches.
  void _initConnectivityWatcher() {
    if (_connectivityWatcher == null) return;

    // Check initial connectivity on boot (cold boot)
    _connectivityWatcher!.isConnected.then((connected) {
      if (_isDisposed) return;
      if (!connected) {
        _wasOffline = true;
      }
    });

    _connectivitySubscription =
        _connectivityWatcher!.onConnectivityChanged.listen((isConnected) {
      if (_isDisposed) return;
      if (!_wasOffline && !isConnected) {
        _wasOffline = true;
      } else if (_wasOffline && isConnected) {
        _wasOffline = false;
        _handleReconnection();
      } else if (isConnected &&
          ((_state is PaginationFullScreenError<T> &&
                  (_state as PaginationFullScreenError<T>).isNetworkError) ||
              (_state is PaginationInlineChunkError<T> &&
                  (_state as PaginationInlineChunkError<T>).isNetworkError))) {
        _wasOffline = false;
        _handleReconnection();
      }
    });
  }

  void _handleReconnection() {
    if (_isDisposed) return;
    final current = _state;
    if (current is PaginationInlineChunkError<T> && current.isNetworkError) {
      fetchNextChunk();
    } else if (current is PaginationFullScreenError<T> && current.isNetworkError) {
      initialLoad();
    }
  }

  /// Initiates or refreshes the pagination stream from the beginning.
  Future<void> initialLoad() async {
    if (_isDisposed) return;
    final epoch = ++_currentEpoch;
    _isFetching = true;
    _currentCursor = null;
    _seenIds.clear();
    _setState(PaginationInitialLoading<T>());

    try {
      final chunk = await NetworkResilience.executeWithRetry(
        action: () => _fetchPageChunk(null, pageSize),
      );

      if (_isDisposed || epoch != _currentEpoch) return; // Stale query check

      final uniqueItems = <T>[];
      for (final item in chunk.items) {
        final id = _idExtractor(item);
        if (_seenIds.add(id)) {
          uniqueItems.add(item);
        }
      }

      _currentCursor = chunk.nextCursor;

      if (!chunk.hasMore || _currentCursor == null) {
        _setState(PaginationExhausted<T>(items: uniqueItems));
      } else {
        _setState(PaginationContentLoaded<T>(
          items: uniqueItems,
          nextCursor: _currentCursor,
        ));
      }
    } catch (error, stackTrace) {
      if (_isDisposed || epoch != _currentEpoch) return;

      final isNetwork = NetworkResilience.isTransientError(error);
      _setState(PaginationFullScreenError<T>(
        error: error,
        stackTrace: stackTrace,
        isNetworkError: isNetwork,
      ));
    } finally {
      if (epoch == _currentEpoch && !_isDisposed) {
        _isFetching = false;
      }
    }
  }

  /// Alias for [initialLoad]. Cancels in-flight queries and reloads from scratch.
  Future<void> refresh() => initialLoad();

  /// Fetches the subsequent page chunk using the active keyset cursor.
  Future<void> fetchNextChunk() async {
    if (_isDisposed) return;
    // Concurrency guard: reject duplicate requests while actively querying.
    if (_isFetching) return;

    final current = _state;
    if (current is PaginationInitialLoading<T> ||
        current is PaginationFullScreenError<T> ||
        current is PaginationExhausted<T> ||
        current is PaginationFetchingNextChunk<T>) {
      return;
    }

    if (_currentCursor == null && current is PaginationContentLoaded<T> && !current.hasMore) {
      return;
    }

    final epoch = _currentEpoch;
    _isFetching = true;
    final existingItems = current.currentItems;

    _setState(PaginationFetchingNextChunk<T>(
      items: existingItems,
      nextCursor: _currentCursor,
    ));

    try {
      final chunk = await NetworkResilience.executeWithRetry(
        action: () => _fetchPageChunk(_currentCursor, pageSize),
      );

      if (_isDisposed || epoch != _currentEpoch) return;

      final newUniqueItems = <T>[];
      for (final item in chunk.items) {
        final id = _idExtractor(item);
        if (_seenIds.add(id)) {
          newUniqueItems.add(item);
        }
      }

      final combinedItems = List<T>.from(existingItems)..addAll(newUniqueItems);
      _currentCursor = chunk.nextCursor;

      if (!chunk.hasMore || _currentCursor == null) {
        _setState(PaginationExhausted<T>(items: combinedItems));
      } else {
        _setState(PaginationContentLoaded<T>(
          items: combinedItems,
          nextCursor: _currentCursor,
        ));
      }
    } catch (error, stackTrace) {
      if (_isDisposed || epoch != _currentEpoch) return;

      final isNetwork = NetworkResilience.isTransientError(error);
      // Preserves existing loaded items while presenting inline retry card
      _setState(PaginationInlineChunkError<T>(
        items: existingItems,
        nextCursor: _currentCursor,
        error: error,
        stackTrace: stackTrace,
        isNetworkError: isNetwork,
      ));
    } finally {
      if (epoch == _currentEpoch && !_isDisposed) {
        _isFetching = false;
      }
    }
  }

  /// Retries the failed operation based on current error state.
  Future<void> retry() async {
    if (_isDisposed) return;
    if (_state is PaginationFullScreenError<T>) {
      return initialLoad();
    } else if (_state is PaginationInlineChunkError<T>) {
      return fetchNextChunk();
    }
  }

  /// Explicit retry for initial full-screen load failure.
  Future<void> retryInitial() => initialLoad();

  /// Explicit retry for inline subsequent chunk failure.
  Future<void> retryNextChunk() => fetchNextChunk();

  /// Attaches a [ScrollController] to automatically fetch chunks when
  /// [ScrollPosition.extentAfter] drops below [prefetchThreshold].
  void attachScrollController(
    ScrollController controller, {
    double prefetchThreshold = 500.0,
  }) {
    detachScrollController();
    _attachedScrollController = controller;
    _prefetchThreshold = prefetchThreshold;

    _scrollListener = () {
      if (_isDisposed) return;
      if (!controller.hasClients || !controller.position.hasContentDimensions) {
        return;
      }
      if (_state is PaginationInlineChunkError<T>) return;

      final position = controller.position;
      if (position.extentAfter < _prefetchThreshold) {
        fetchNextChunk();
      }
    };

    controller.addListener(_scrollListener!);
  }

  /// Detaches the registered [ScrollController].
  void detachScrollController() {
    if (_attachedScrollController != null && _scrollListener != null) {
      _attachedScrollController!.removeListener(_scrollListener!);
      _scrollListener = null;
      _attachedScrollController = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime Fine-Grained In-Place Mutation Support (<50ms UI update)
  // ---------------------------------------------------------------------------

  /// Inserts a newly received item into memory without triggering a network fetch.
  void insertItem(T item, {bool prepend = true}) {
    if (_isDisposed) return;
    final id = _idExtractor(item);
    _seenIds.add(id);

    final currentItems = List<T>.from(_state.currentItems);
    if (prepend) {
      currentItems.insert(0, item);
    } else {
      currentItems.add(item);
    }

    _updateItemsInCurrentState(currentItems);
  }

  /// Updates an existing item in memory in-place (<50ms execution).
  void updateItem(T updatedItem) {
    if (_isDisposed) return;
    final targetId = _idExtractor(updatedItem);
    final currentItems = List<T>.from(_state.currentItems);
    final index = currentItems.indexWhere((it) => _idExtractor(it) == targetId);

    if (index != -1) {
      currentItems[index] = updatedItem;
      _updateItemsInCurrentState(currentItems);
    }
  }

  /// Removes an item from memory in-place.
  void removeItem(String id) {
    if (_isDisposed) return;
    _seenIds.remove(id);
    final currentItems = List<T>.from(_state.currentItems);
    final beforeLength = currentItems.length;
    currentItems.removeWhere((it) => _idExtractor(it) == id);

    if (currentItems.length != beforeLength) {
      _updateItemsInCurrentState(currentItems);
    }
  }

  void _updateItemsInCurrentState(List<T> newItems) {
    if (_isDisposed) return;
    final current = _state;
    switch (current) {
      case PaginationInitialLoading<T>():
        break;
      case PaginationContentLoaded<T>():
        _setState(PaginationContentLoaded<T>(
          items: newItems,
          nextCursor: current.nextCursor,
        ));
      case PaginationFetchingNextChunk<T>():
        _setState(PaginationFetchingNextChunk<T>(
          items: newItems,
          nextCursor: current.nextCursor,
        ));
      case PaginationInlineChunkError<T>():
        _setState(PaginationInlineChunkError<T>(
          items: newItems,
          nextCursor: current.nextCursor,
          error: current.error,
          stackTrace: current.stackTrace,
          isNetworkError: current.isNetworkError,
        ));
      case PaginationFullScreenError<T>():
        break;
      case PaginationExhausted<T>():
        _setState(PaginationExhausted<T>(items: newItems));
    }
  }

  void _setState(PaginationState<T> newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    detachScrollController();
    super.dispose();
  }
}
