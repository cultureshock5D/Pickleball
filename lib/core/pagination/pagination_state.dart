import 'keyset_cursor.dart';

/// Sealed class hierarchy representing the 6 distinct states of [PaginationController].
sealed class PaginationState<T> {
  const PaginationState();

  /// Loaded items for the current state. Empty during initial loading or full screen error.
  List<T> get currentItems;

  /// Convenience getters for state inspections.
  bool get isInitialLoading => this is PaginationInitialLoading<T>;
  bool get isContentLoaded => this is PaginationContentLoaded<T>;
  bool get isFetchingNextChunk => this is PaginationFetchingNextChunk<T>;
  bool get isInlineChunkError => this is PaginationInlineChunkError<T>;
  bool get isFullScreenError => this is PaginationFullScreenError<T>;
  bool get isExhausted => this is PaginationExhausted<T>;
}

/// 1. Initial page load in progress (empty list). Renders full-screen skeleton placeholder.
class PaginationInitialLoading<T> extends PaginationState<T> {
  const PaginationInitialLoading();

  @override
  List<T> get currentItems => const [];

  @override
  String toString() => 'PaginationInitialLoading<$T>()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PaginationInitialLoading<T>;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// 2. Successfully loaded content with active cursor. More chunks can be requested.
class PaginationContentLoaded<T> extends PaginationState<T> {
  final List<T> items;
  final KeysetCursor? nextCursor;

  const PaginationContentLoaded({
    required this.items,
    this.nextCursor,
  });

  @override
  List<T> get currentItems => items;

  bool get hasMore => nextCursor != null;

  @override
  String toString() =>
      'PaginationContentLoaded<$T>(items: ${items.length}, nextCursor: $nextCursor)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginationContentLoaded<T>) return false;
    if (items.length != other.items.length) return false;
    for (int i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return nextCursor == other.nextCursor;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), nextCursor);
}

/// 3. Active fetch of the next chunk triggered by prefetch scroll telemetry.
/// Retains existing items in memory while displaying non-blocking footer loading indicator.
class PaginationFetchingNextChunk<T> extends PaginationState<T> {
  final List<T> items;
  final KeysetCursor? nextCursor;

  const PaginationFetchingNextChunk({
    required this.items,
    this.nextCursor,
  });

  @override
  List<T> get currentItems => items;

  @override
  String toString() =>
      'PaginationFetchingNextChunk<$T>(items: ${items.length}, nextCursor: $nextCursor)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginationFetchingNextChunk<T>) return false;
    if (items.length != other.items.length) return false;
    for (int i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return nextCursor == other.nextCursor;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), nextCursor);
}

/// 4. Subsequent chunk fetch failed (e.g., timeout or offline drop mid-scroll).
/// Preserves loaded items, records error details, and presents non-blocking inline footer retry.
class PaginationInlineChunkError<T> extends PaginationState<T> {
  final List<T> items;
  final KeysetCursor? nextCursor;
  final Object error;
  final StackTrace? stackTrace;
  final bool isNetworkError;

  const PaginationInlineChunkError({
    required this.items,
    this.nextCursor,
    required this.error,
    this.stackTrace,
    this.isNetworkError = false,
  });

  @override
  List<T> get currentItems => items;

  /// User-friendly error message description.
  String get message => error.toString();

  @override
  String toString() =>
      'PaginationInlineChunkError<$T>(items: ${items.length}, error: $error, isNetworkError: $isNetworkError)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginationInlineChunkError<T>) return false;
    if (items.length != other.items.length) return false;
    for (int i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return nextCursor == other.nextCursor &&
        error.toString() == other.error.toString() &&
        isNetworkError == other.isNetworkError;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(items),
        nextCursor,
        error.toString(),
        isNetworkError,
      );
}

/// 5. Initial load failed completely (no loaded items). Renders full-screen error with retry button.
class PaginationFullScreenError<T> extends PaginationState<T> {
  final Object error;
  final StackTrace? stackTrace;
  final bool isNetworkError;

  const PaginationFullScreenError({
    required this.error,
    this.stackTrace,
    this.isNetworkError = false,
  });

  @override
  List<T> get currentItems => const [];

  /// User-friendly error message description.
  String get message => error.toString();

  @override
  String toString() =>
      'PaginationFullScreenError<$T>(error: $error, isNetworkError: $isNetworkError)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginationFullScreenError<T>) return false;
    return error.toString() == other.error.toString() &&
        isNetworkError == other.isNetworkError;
  }

  @override
  int get hashCode => Object.hash(error.toString(), isNetworkError);
}

/// 6. All items have been fetched (cursor is exhausted). Renders complete list and ceases prefetch.
class PaginationExhausted<T> extends PaginationState<T> {
  final List<T> items;

  const PaginationExhausted({
    required this.items,
  });

  @override
  List<T> get currentItems => items;

  @override
  String toString() => 'PaginationExhausted<$T>(items: ${items.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginationExhausted<T>) return false;
    if (items.length != other.items.length) return false;
    for (int i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}
