import 'package:flutter/material.dart';

import '../../../../widgets/zzz_gif_decoration.dart';

export '../../../../widgets/zzz_gif_decoration.dart';
import '../../../updates/presentation/hot_update_image.dart';
import '../../domain/planner_models.dart';

// ── ZZZ Spec helpers ──────────────────────────────────────────────────────
ZzzGifSpec zzzSpecForEvent(PlannerEvent event) {
  final seed = Object.hash(event.id, event.title, event.startsAt.day);
  return zzzGifSpecs[seed.abs() % zzzGifSpecs.length];
}

ZzzGifSpec zzzSpecForTodo(PlannerTodo todo) {
  final seed = Object.hash(todo.id, todo.title, todo.completed);
  return zzzGifSpecs[seed.abs() % zzzGifSpecs.length];
}

// ── Shared helpers ────────────────────────────────────────────────────────
String timeLabel(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

Color colorFromHex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

// ── ZZZ Led Marquee ───────────────────────────────────────────────────────
class ZzzLedMarquee extends StatelessWidget {
  const ZzzLedMarquee({super.key, required this.date});

  final DateTime date;

  String get _weekday {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final ds =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $_weekday';
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: zzzGreen.withValues(alpha: 0.06),
            border: Border(
              top: BorderSide(color: zzzGreen.withValues(alpha: 0.55), width: 1.5),
              bottom: BorderSide(color: zzzGreen.withValues(alpha: 0.55), width: 1.5),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 20, height: 1, color: zzzRed.withValues(alpha: 0.6)),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: zzzRed.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: zzzRed.withValues(alpha: 0.7), width: 1.5),
                    ),
                  ),
                  Container(width: 20, height: 1, color: zzzRed.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ZEZ-TZDRIVER — $ds',
                style: const TextStyle(
                  color: zzzGreen,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── ZZZ Side Art ──────────────────────────────────────────────────────────
class ZzzSideArt extends StatelessWidget {
  const ZzzSideArt({super.key, required this.spec, required this.opacity});

  final ZzzGifSpec spec;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: opacity,
            child: HotUpdateImage(
              resourceId: spec.resourceId,
              fallbackAsset: spec.asset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  zzzBgColor,
                  Color(0x990A0A0F),
                  Color(0x000A0A0F),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ZZZ Action Button ─────────────────────────────────────────────────────
class ZzzActionButton extends StatelessWidget {
  const ZzzActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              zzzGreen.withValues(alpha: 0.13),
              zzzGreen.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: zzzGreen.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: zzzGreen.withValues(alpha: 0.1),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: zzzGreen.withValues(alpha: 0.85)),
            const SizedBox(width: 4),
            if (isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: zzzGreen,
                ),
              )
            else
              Text(
                '> $label',
                style: const TextStyle(
                  color: zzzGreen,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── ZZZ Editor Button ─────────────────────────────────────────────────────
class ZzzEditorButton extends StatelessWidget {
  const ZzzEditorButton({
    super.key,
    required this.label,
    this.primary = false,
    this.onPressed,
  });

  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: primary
              ? zzzRed.withValues(alpha: 0.18)
              : zzzGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: primary
                ? zzzRed.withValues(alpha: 0.55)
                : zzzGreen.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          '> $label',
          style: TextStyle(
            color: primary ? zzzRed : zzzGreen,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── ZZZ Capsule Clipper ───────────────────────────────────────────────────
class ZzzCapsuleClipper extends CustomClipper<Path> {
  const ZzzCapsuleClipper({required this.chamfer});

  final double chamfer;

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(chamfer, 0);
    path.lineTo(w - chamfer, 0);
    path.lineTo(w, chamfer);
    path.lineTo(w, h - chamfer);
    path.lineTo(w - chamfer, h);
    path.lineTo(chamfer, h);
    path.lineTo(0, h - chamfer);
    path.lineTo(0, chamfer);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── ZZZ Scanline Painter ──────────────────────────────────────────────────
class ZzzScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0D00FF41)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
