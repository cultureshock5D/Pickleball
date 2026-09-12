import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/network_connectivity_watcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Luxury sports-tech animated top network connectivity indicator and wrapper.
/// Displays a sleek status pill at the top of the viewport when connection is lost
/// and announces reconnection when connection is restored before smoothly auto-dismissing.
class NetworkStatusOverlay extends StatefulWidget {
  final Widget child;
  final NetworkConnectivityWatcher? connectivityWatcher;
  final Duration autoDismissDelay;

  const NetworkStatusOverlay({
    super.key,
    required this.child,
    this.connectivityWatcher,
    this.autoDismissDelay = const Duration(seconds: 3),
  });

  @override
  State<NetworkStatusOverlay> createState() => _NetworkStatusOverlayState();
}

class _NetworkStatusOverlayState extends State<NetworkStatusOverlay> {
  late final NetworkConnectivityWatcher _watcher;
  late final bool _isExternalWatcher;
  StreamSubscription<bool>? _subscription;
  Timer? _dismissTimer;

  bool _isOffline = false;
  bool _showBanner = false;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _isExternalWatcher = widget.connectivityWatcher != null;
    _watcher = widget.connectivityWatcher ?? DefaultNetworkConnectivityWatcher();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final connected = await _watcher.isConnected;
    if (!mounted) return;

    if (!connected) {
      setState(() {
        _isOffline = true;
        _showBanner = true;
        _wasOffline = true;
      });
    }

    _subscription = _watcher.onConnectivityChanged.listen((connected) {
      if (!mounted) return;

      _dismissTimer?.cancel();

      if (!connected) {
        setState(() {
          _isOffline = true;
          _showBanner = true;
          _wasOffline = true;
        });
      } else if (_wasOffline) {
        // Just transitioned back online from offline state
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
        // Initial online state - keep banner hidden
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
    if (!_isExternalWatcher) {
      _watcher.dispose();
    }
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
class NetworkStatusPill extends StatelessWidget {
  final bool isOffline;

  const NetworkStatusPill({
    super.key,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isOffline
        ? (isDark ? const Color(0xFF241510) : const Color(0xFFFFF3E0))
        : (isDark ? const Color(0xFF0F2418) : const Color(0xFFE8F5E9));

    final borderColor = isOffline
        ? AppColors.warningAmber.withValues(alpha: isDark ? 0.6 : 0.4)
        : AppTheme.neonLime.withValues(alpha: isDark ? 0.8 : 0.6);

    final iconColor = isOffline
        ? AppColors.warningAmber
        : (isDark ? AppTheme.neonLime : AppColors.courtSuccess);

    final textColor = isOffline
        ? (isDark ? const Color(0xFFFFB74D) : const Color(0xFFD84315))
        : (isDark ? AppTheme.neonLime : AppColors.courtSuccess);

    final label = isOffline
        ? "You're offline • Showing cached data"
        : 'Back online • Syncing data';

    final icon = isOffline
        ? Icons.wifi_off_rounded
        : Icons.wifi_rounded;

    return Semantics(
      label: label,
      liveRegion: true,
      child: Container(
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
            Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 8),
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
      ),
    );
  }
}
