import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/network_connectivity_watcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/connectivity_service.dart';

/// Luxury sports-tech animated top network connectivity indicator and wrapper.
/// Overlays the app globally via MaterialApp.builder, displaying real-time
/// reachability and immediate-sync pipeline states:
/// - Offline: Persistent amber/red banner ("Offline Mode — Transactions saving locally to SQLite").
/// - Syncing: Transient blue banner with spinner ("Online — Syncing pending records to Supabase...").
/// - Synced: Green banner ("Connected & Synced") that auto-dismisses after 3 seconds.
/// - Sync Error: Interactive tap-to-retry banner ("Sync Error — Tap to retry").
class NetworkStatusOverlay extends StatefulWidget {
  final Widget child;
  final NetworkConnectivityWatcher? connectivityWatcher;
  final ConnectivityService? connectivityService;
  final Duration autoDismissDelay;

  const NetworkStatusOverlay({
    super.key,
    required this.child,
    this.connectivityWatcher,
    this.connectivityService,
    this.autoDismissDelay = const Duration(seconds: 3),
  });

  @override
  State<NetworkStatusOverlay> createState() => _NetworkStatusOverlayState();
}

class _NetworkStatusOverlayState extends State<NetworkStatusOverlay> {
  // Legacy watcher for backwards compatibility with existing test suites
  NetworkConnectivityWatcher? _watcher;
  StreamSubscription<bool>? _subscription;

  // Primary reactive service for POS reachability & sync states
  ConnectivityService? _service;

  Timer? _dismissTimer;

  bool _isOffline = false;
  bool _showBanner = false;
  bool _wasOffline = false;
  SyncState _currentSyncState = SyncState.idle;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    if (widget.connectivityWatcher != null) {
      // Legacy watcher mode for existing test compatibility
      _watcher = widget.connectivityWatcher;
      _initLegacyWatcher();
    } else {
      // Modern ConnectivityService mode
      _service = widget.connectivityService ?? ConnectivityService.instance;
      _service!.addListener(_onServiceStateChanged);
      _syncInitialServiceState();
    }
  }

  void _syncInitialServiceState() {
    final s = _service!;
    final online = s.isOnline;
    final syncState = s.syncState;

    if (!online) {
      _isOffline = true;
      _showBanner = true;
      _wasOffline = true;
      _currentSyncState = syncState;
    } else if (syncState == SyncState.syncing || syncState == SyncState.error) {
      _isOffline = false;
      _showBanner = true;
      _currentSyncState = syncState;
      _syncError = s.lastSyncError;
    } else {
      _isOffline = false;
      _showBanner = false;
      _currentSyncState = syncState;
    }
  }

  void _onServiceStateChanged() {
    if (!mounted || _service == null) return;

    final s = _service!;
    final online = s.isOnline;
    final syncState = s.syncState;
    final error = s.lastSyncError;

    _dismissTimer?.cancel();

    setState(() {
      _currentSyncState = syncState;
      _syncError = error;

      if (!online) {
        _isOffline = true;
        _showBanner = true;
        _wasOffline = true;
      } else if (syncState == SyncState.syncing) {
        _isOffline = false;
        _showBanner = true;
      } else if (syncState == SyncState.error) {
        _isOffline = false;
        _showBanner = true;
      } else if (_wasOffline || _showBanner) {
        // Just came back online and finished syncing
        _isOffline = false;
        _showBanner = true;
        _wasOffline = false;

        _dismissTimer = Timer(widget.autoDismissDelay, () {
          if (mounted) {
            setState(() {
              _showBanner = false;
            });
          }
        });
      } else {
        _isOffline = false;
        _showBanner = false;
      }
    });
  }

  Future<void> _initLegacyWatcher() async {
    final connected = await _watcher!.isConnected;
    if (!mounted) return;

    if (!connected) {
      setState(() {
        _isOffline = true;
        _showBanner = true;
        _wasOffline = true;
      });
    }

    _subscription = _watcher!.onConnectivityChanged.listen((connected) {
      if (!mounted) return;

      _dismissTimer?.cancel();

      if (!connected) {
        setState(() {
          _isOffline = true;
          _showBanner = true;
          _wasOffline = true;
        });
      } else if (_wasOffline) {
        setState(() {
          _isOffline = false;
          _showBanner = true;
          _wasOffline = false;
        });

        _dismissTimer = Timer(widget.autoDismissDelay, () {
          if (mounted) {
            setState(() {
              _showBanner = false;
            });
          }
        });
      } else {
        setState(() {
          _isOffline = false;
          _showBanner = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _subscription?.cancel();
    _service?.removeListener(_onServiceStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              ignoring: !_showBanner,
              child: AnimatedSlide(
                offset: _showBanner ? Offset.zero : const Offset(0, -1.3),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _showBanner ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Center(
                      child: NetworkStatusPill(
                        isOffline: _isOffline,
                        syncState: _service != null ? _currentSyncState : null,
                        errorMessage: _syncError,
                        onRetry: () => _service?.retrySync(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Standalone visual pill displaying network status badge.
/// Displays accessible semantic tokens, icons, and micro-spinners for synchronization.
class NetworkStatusPill extends StatelessWidget {
  final bool isOffline;
  final SyncState? syncState;
  final String? customLabel;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const NetworkStatusPill({
    super.key,
    required this.isOffline,
    this.syncState,
    this.customLabel,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine state presentation
    final Color bgColor;
    final Color borderColor;
    final Color iconColor;
    final Color textColor;
    final String label;
    final IconData iconData;
    final bool isSpinning;

    if (customLabel != null) {
      label = customLabel!;
      iconData = isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded;
      isSpinning = false;
      bgColor = isOffline
          ? (isDark ? const Color(0xFF241510) : const Color(0xFFFFF3E0))
          : (isDark ? const Color(0xFF0F2418) : const Color(0xFFE8F5E9));
      borderColor = isOffline
          ? AppColors.warningAmber.withValues(alpha: isDark ? 0.6 : 0.4)
          : AppTheme.neonLime.withValues(alpha: isDark ? 0.8 : 0.6);
      iconColor = isOffline
          ? AppColors.warningAmber
          : (isDark ? AppTheme.neonLime : AppColors.courtSuccess);
      textColor = iconColor;
    } else if (syncState != null) {
      if (isOffline) {
        label = 'Offline Mode — Transactions saving locally to SQLite';
        iconData = Icons.cloud_off_rounded;
        isSpinning = false;
        bgColor = isDark ? const Color(0xFF2A1710) : const Color(0xFFFFF3E0);
        borderColor = AppColors.warningAmber.withValues(alpha: isDark ? 0.8 : 0.6);
        iconColor = AppColors.warningAmber;
        textColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
      } else if (syncState == SyncState.syncing) {
        label = 'Online — Syncing pending records to Supabase...';
        iconData = Icons.sync_rounded;
        isSpinning = true;
        bgColor = isDark ? const Color(0xFF0D1E2A) : const Color(0xFFE1F5FE);
        borderColor = Colors.lightBlueAccent.withValues(alpha: isDark ? 0.8 : 0.6);
        iconColor = Colors.lightBlueAccent;
        textColor = isDark ? Colors.lightBlueAccent : const Color(0xFF0277BD);
      } else if (syncState == SyncState.error) {
        label = errorMessage != null && errorMessage!.isNotEmpty
            ? 'Sync issue: $errorMessage • Tap to retry'
            : 'Sync issue — Tap to retry';
        iconData = Icons.sync_problem_rounded;
        isSpinning = false;
        bgColor = isDark ? const Color(0xFF2E1215) : const Color(0xFFFFEBEE);
        borderColor = AppColors.saleRed.withValues(alpha: isDark ? 0.8 : 0.6);
        iconColor = AppColors.saleRed;
        textColor = isDark ? const Color(0xFFFF8A80) : AppColors.saleRed;
      } else {
        // Connected & Synced
        label = 'Connected & Synced';
        iconData = Icons.check_circle_rounded;
        isSpinning = false;
        bgColor = isDark ? const Color(0xFF0F2418) : const Color(0xFFE8F5E9);
        borderColor = AppTheme.neonLime.withValues(alpha: isDark ? 0.8 : 0.6);
        iconColor = isDark ? AppTheme.neonLime : AppColors.courtSuccess;
        textColor = iconColor;
      }
    } else {
      // Legacy fallback for tests
      label = isOffline
          ? "You're offline • Showing cached data"
          : 'Back online • Syncing data';
      iconData = isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded;
      isSpinning = false;
      bgColor = isOffline
          ? (isDark ? const Color(0xFF241510) : const Color(0xFFFFF3E0))
          : (isDark ? const Color(0xFF0F2418) : const Color(0xFFE8F5E9));
      borderColor = isOffline
          ? AppColors.warningAmber.withValues(alpha: isDark ? 0.6 : 0.4)
          : AppTheme.neonLime.withValues(alpha: isDark ? 0.8 : 0.6);
      iconColor = isOffline
          ? AppColors.warningAmber
          : (isDark ? AppTheme.neonLime : AppColors.courtSuccess);
      textColor = isOffline
          ? (isDark ? const Color(0xFFFFB74D) : const Color(0xFFD84315))
          : (isDark ? AppTheme.neonLime : AppColors.courtSuccess);
    }

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: (isOffline ? Colors.orange : Colors.green).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSpinning)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                iconData,
                size: 16,
                color: iconColor,
              ),
            ),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onRetry != null && syncState == SyncState.error) {
      content = InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(9999),
        child: content,
      );
    }

    return Semantics(
      label: label,
      liveRegion: true,
      button: onRetry != null && syncState == SyncState.error,
      child: content,
    );
  }
}
