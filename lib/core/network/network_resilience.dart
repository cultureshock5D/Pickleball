import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Exception thrown when an operation exceeds the 8-second clamped network timeout.
class ClampedTimeoutException implements Exception {
  final Duration timeout;
  final String message;

  const ClampedTimeoutException({
    this.timeout = const Duration(seconds: 8),
    this.message = 'Network request exceeded the 8-second timeout threshold.',
  });

  @override
  String toString() => 'ClampedTimeoutException: $message ($timeout)';
}

/// Network resilience engine providing 8-second clamped timeouts and
/// jittered exponential backoff retry policies for transient failures.
class NetworkResilience {
  NetworkResilience._();

  /// 8-second clamped timeout threshold.
  static const Duration clampedTimeout = Duration(seconds: 8);

  /// Default retry count.
  static const int defaultMaxRetries = 3;

  /// Base backoff interval (500ms).
  static const Duration defaultBaseDelay = Duration(milliseconds: 500);

  /// Maximum backoff cap (4s).
  static const Duration defaultMaxDelay = Duration(seconds: 4);

  /// Identifies whether an error is transient (network disconnect, timeout, 5xx).
  static bool isTransientError(Object error) {
    if (error is TimeoutException || error is ClampedTimeoutException) {
      return true;
    }
    if (error is SocketException) {
      return true;
    }
    final errStr = error.toString().toLowerCase();
    return errStr.contains('socketexception') ||
        errStr.contains('connection refused') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('clientexception') ||
        errStr.contains('connection reset') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('timed out') ||
        errStr.contains('timeout') ||
        errStr.contains('500') ||
        errStr.contains('502') ||
        errStr.contains('503') ||
        errStr.contains('504');
  }

  /// Executes an [action] clamped to an 8-second timeout, retrying transient errors
  /// with jittered exponential backoff.
  ///
  /// - [maxRetries]: Maximum number of retry attempts (default: 3).
  /// - [baseDelay]: Initial retry backoff interval (default: 500ms).
  /// - [maxDelay]: Maximum backoff cap (default: 4s).
  /// - [timeout]: Clamped timeout per execution attempt (default: 8s).
  /// - [random]: Optional RNG for deterministic backoff assertion in tests.
  /// - [onRetry]: Optional callback invoked prior to each retry delay.
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() action,
    int maxRetries = defaultMaxRetries,
    Duration baseDelay = defaultBaseDelay,
    Duration maxDelay = defaultMaxDelay,
    Duration timeout = clampedTimeout,
    Random? random,
    void Function(int attempt, Object error, Duration delay)? onRetry,
  }) async {
    final effectiveTimeout =
        timeout < clampedTimeout ? timeout : clampedTimeout;
    final rng = random ?? Random();
    int attempt = 0;

    while (true) {
      try {
        return await action().timeout(
          effectiveTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Operation timed out after $effectiveTimeout',
              effectiveTimeout,
            );
          },
        );
      } catch (error, stackTrace) {
        if (!isTransientError(error) || attempt >= maxRetries) {
          Error.throwWithStackTrace(error, stackTrace);
        }

        attempt++;
        // Exponential factor: baseDelay * 2^(attempt - 1)
        final multiplier = 1 << (attempt - 1);
        final rawDelayMs = min(
          maxDelay.inMilliseconds,
          baseDelay.inMilliseconds * multiplier,
        );
        // Half-jitter strategy: interval in [rawDelayMs / 2, rawDelayMs]
        final half = rawDelayMs ~/ 2;
        final jitter = rng.nextInt(half > 0 ? half + 1 : 1);
        final delayMs = half + jitter;
        final delay = Duration(milliseconds: delayMs);

        if (onRetry != null) {
          onRetry(attempt, error, delay);
        }

        await Future.delayed(delay);
      }
    }
  }
}
