import 'package:flutter/material.dart';

/// 主题无关的加载指示器颜色
/// ZZZ主题使用终端绿，Material主题使用主题色
Color _loadingColor(BuildContext context, {bool isZzz = false}) {
  if (isZzz) return const Color(0xFF00FF41);
  return Theme.of(context).colorScheme.primary;
}

// ── 全屏居中加载 ────────────────────────────────────────────────────────

/// 全屏居中加载指示器，带可选提示文字
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    this.message,
    this.isZzz = false,
  });

  final String? message;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final color = _loadingColor(context, isZzz: isZzz);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: isZzz
                    ? const Color(0xFF00FF41).withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontFamily: isZzz ? 'monospace' : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 页面级骨架加载 ──────────────────────────────────────────────────────

/// 顶部 LinearProgressIndicator + 居中 spinner 组合
class AppPageLoading extends StatelessWidget {
  const AppPageLoading({
    super.key,
    this.message,
    this.isZzz = false,
  });

  final String? message;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildLinearProgress(context),
        Expanded(
          child: AppLoadingOverlay(message: message, isZzz: isZzz),
        ),
      ],
    );
  }

  Widget _buildLinearProgress(BuildContext context) {
    final color = _loadingColor(context, isZzz: isZzz);
    return LinearProgressIndicator(
      minHeight: 2,
      valueColor: AlwaysStoppedAnimation(color),
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}

// ── 内联小加载指示器 ────────────────────────────────────────────────────

/// 小号加载指示器，用于列表项或按钮旁
class AppInlineLoading extends StatelessWidget {
  const AppInlineLoading({
    super.key,
    this.size = 18,
    this.isZzz = false,
  });

  final double size;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final color = _loadingColor(context, isZzz: isZzz);
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

// ── 加载按钮封装 ────────────────────────────────────────────────────────

/// 自动处理 loading 状态的按钮
/// loading=true 时显示 spinner 并禁用交互
class AppLoadingButton extends StatelessWidget {
  const AppLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.isZzz = false,
    this.icon,
    this.variant = _ButtonVariant.filled,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool isZzz;
  final IconData? icon;
  final _ButtonVariant variant;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final color = _loadingColor(context, isZzz: isZzz);
    final effectiveOnPressed = loading ? null : onPressed;

    Widget child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(icon, size: 18),
          ),
        Text(
          loading ? '处理中...' : label,
          style: TextStyle(
            fontFamily: isZzz ? 'monospace' : null,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );

    if (isZzz) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        child: OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00FF41),
            side: BorderSide(
              color: const Color(0xFF00FF41).withValues(alpha: loading ? 0.3 : 0.6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: child,
        ),
      );
    }

    switch (variant) {
      case _ButtonVariant.filled:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: FilledButton(
            onPressed: effectiveOnPressed,
            child: child,
          ),
        );
      case _ButtonVariant.tonal:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: FilledButton.tonal(
            onPressed: effectiveOnPressed,
            child: child,
          ),
        );
      case _ButtonVariant.outlined:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          child: OutlinedButton(
            onPressed: effectiveOnPressed,
            child: child,
          ),
        );
    }
  }
}

enum _ButtonVariant { filled, tonal, outlined }

// ── 骨架屏占位块 ────────────────────────────────────────────────────────

/// 带动画的骨架屏矩形块
class AppSkeletonBlock extends StatefulWidget {
  const AppSkeletonBlock({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 6,
    this.isZzz = false,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final bool isZzz;

  @override
  State<AppSkeletonBlock> createState() => _AppSkeletonBlockState();
}

class _AppSkeletonBlockState extends State<AppSkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isZzz
        ? const Color(0xFF00FF41).withValues(alpha: 0.08)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: _animation.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

// ── 骨架屏卡片 ──────────────────────────────────────────────────────────

/// 模拟卡片内容的骨架屏
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({
    super.key,
    this.lines = 3,
    this.isZzz = false,
  });

  final int lines;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeletonBlock(width: 160, height: 16, isZzz: isZzz),
            const SizedBox(height: 12),
            for (int i = 0; i < lines - 1; i++) ...[
              AppSkeletonBlock(
                width: i == lines - 2 ? 120 : double.infinity,
                height: 12,
                isZzz: isZzz,
              ),
              if (i < lines - 2) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 骨架屏列表 ──────────────────────────────────────────────────────────

/// 条目数可配置的骨架屏列表
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.count = 4,
    this.isZzz = false,
  });

  final int count;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => AppSkeletonCard(
        lines: 3,
        isZzz: isZzz,
      ),
    );
  }
}

