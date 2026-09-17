import 'package:flutter/material.dart';

/// Standard responsive design breakpoints for the application.
class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  /// Minimum width considered a tablet or dual-pane layout.
  static const double tablet = 650.0;

  /// Minimum width considered a desktop or wide landscape display.
  static const double desktop = 960.0;

  /// Maximum optimal reading/content width to prevent unnaturally stretched layouts.
  static const double maxContentWidth = 1040.0;

  /// Standard compact maximum width for focused forms and checkout cards.
  static const double maxFormWidth = 640.0;
}

/// A responsive container that centers its child and clamps it to [maxWidth].
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    return Center(
      child: content,
    );
  }
}

/// Responsive builder that switches between a compact single-column layout
/// and an expanded multi-column or split layout based on [LayoutBuilder] constraints.
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) compact;
  final Widget Function(BuildContext context, BoxConstraints constraints)? expanded;
  final double breakpoint;

  const ResponsiveLayoutBuilder({
    super.key,
    required this.compact,
    this.expanded,
    this.breakpoint = ResponsiveBreakpoints.tablet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint && expanded != null) {
          return expanded!(context, constraints);
        }
        return compact(context, constraints);
      },
    );
  }
}
