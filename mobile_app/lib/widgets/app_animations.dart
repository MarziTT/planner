import 'package:flutter/material.dart';

/// Premium animation curves shared across the app.
class AppCurves {
  static const easeOutExpo = Cubic(0.16, 1, 0.3, 1);
  static const easeOutBack = Cubic(0.34, 1.56, 0.64, 1);
  static const spring = Curves.elasticOut;
}

// ── AnimatedSwitcher wrapper ─────────────────────────────────────────────

/// Wraps child in AnimatedSwitcher with a consistent fade+slide-up transition.
/// When [key] changes (e.g. loading→content, content→error),
/// the transition plays automatically.
class AppStateSwitcher extends StatelessWidget {
  const AppStateSwitcher({
    super.key,
    required this.stateKey,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
  });

  /// A key that uniquely identifies the current state.
  /// Change this to trigger the transition.
  final Key stateKey;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      key: stateKey,
      duration: duration,
      switchInCurve: AppCurves.easeOutExpo,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AppCurves.easeOutExpo,
            )),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ── Staggered list item builder ──────────────────────────────────────────

/// Builds a list with staggered fade-in+slide-up animation.
///
/// Usage:
/// ```dart
/// AppStaggeredList(
///   itemCount: items.length,
///   itemBuilder: (context, index, animation) => FadeTransition(
///     opacity: animation,
///     child: YourListItem(...),
///   ),
/// )
/// ```
class AppStaggeredList extends StatefulWidget {
  const AppStaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.initialDelay = const Duration(milliseconds: 80),
    this.staggerDelay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 400),
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.separatorBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index, Animation<double> animation) itemBuilder;
  final Duration initialDelay;
  final Duration staggerDelay;
  final Duration duration;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final Widget Function(BuildContext, int)? separatorBuilder;

  @override
  State<AppStaggeredList> createState() => _AppStaggeredListState();
}

class _AppStaggeredListState extends State<AppStaggeredList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration +
          widget.staggerDelay * (widget.itemCount.clamp(0, 20)),
      vsync: this,
    );
    Future.delayed(widget.initialDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.separatorBuilder != null) {
      return ListView.separated(
        padding: widget.padding,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        itemCount: widget.itemCount,
        separatorBuilder: widget.separatorBuilder!,
        itemBuilder: (context, index) => _buildItem(context, index),
      );
    }
    return ListView.builder(
      padding: widget.padding,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) => _buildItem(context, index),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final itemDelay = widget.staggerDelay * index;
    final start = itemDelay.inMilliseconds /
        (widget.duration.inMilliseconds +
            widget.staggerDelay.inMilliseconds * widget.itemCount.clamp(0, 20));

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start.clamp(0, 0.95), 1.0, curve: AppCurves.easeOutExpo),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - curved.value)),
            child: child,
          ),
        );
      },
      child: widget.itemBuilder(context, index, curved),
    );
  }
}

// ── Hero-style shared element wrapper ────────────────────────────────────

/// A simple tag-based hero animation for list→detail transitions.
class AppHero extends StatelessWidget {
  const AppHero({
    super.key,
    required this.tag,
    required this.child,
  });

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (flightContext, animation, flightDirection,
          fromHeroContext, toHeroContext) {
        return FadeTransition(
          opacity: animation,
          child: toHeroContext.widget,
        );
      },
      child: child,
    );
  }
}
