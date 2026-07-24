import 'package:flutter/material.dart';

import '../features/updates/presentation/hot_update_image.dart';

// --- ZZZ Color Constants ---
const zzzBgColor = Color(0xFF0A0A0F);
const zzzSurfaceColor = Color(0xFF0D0B12);
const zzzRed = Color(0xFFFF1744);
const zzzGreen = Color(0xFF00FF41);
const zzzGreenLight = Color(0xFFE0F0E0);
const zzzTextColor = Color(0xFFE0F0E0);
const zzzSilver = Color(0xFFC8C8D8);

// --- ZZZ GIF Spec ---
class ZzzGifSpec {
  const ZzzGifSpec(this.resourceId, this.asset, this.label);

  final String resourceId;
  final String asset;
  final String label;
}

const zzzGifSpecs = <ZzzGifSpec>[
  ZzzGifSpec('zzz.10号', 'assets/themes/zzz/10号.gif', '10号'),
  ZzzGifSpec('zzz.11号', 'assets/themes/zzz/11号.gif', '11号'),
  ZzzGifSpec('zzz.12号', 'assets/themes/zzz/12号.gif', '12号'),
  ZzzGifSpec('zzz.13', 'assets/themes/zzz/13.gif', '13'),
  ZzzGifSpec('zzz.14', 'assets/themes/zzz/14.gif', '14'),
  ZzzGifSpec('zzz.15', 'assets/themes/zzz/15.gif', '15'),
  ZzzGifSpec('zzz.16', 'assets/themes/zzz/16.gif', '16'),
  ZzzGifSpec('zzz.17', 'assets/themes/zzz/17.gif', '17'),
  ZzzGifSpec('zzz.18', 'assets/themes/zzz/18.gif', '18'),
  ZzzGifSpec('zzz.19', 'assets/themes/zzz/19.gif', '19'),
  ZzzGifSpec('zzz.1号', 'assets/themes/zzz/1号.gif', '1号'),
  ZzzGifSpec('zzz.20', 'assets/themes/zzz/20.gif', '20'),
  ZzzGifSpec('zzz.21', 'assets/themes/zzz/21.gif', '21'),
  ZzzGifSpec('zzz.22', 'assets/themes/zzz/22.gif', '22'),
  ZzzGifSpec('zzz.23', 'assets/themes/zzz/23.gif', '23'),
  ZzzGifSpec('zzz.24', 'assets/themes/zzz/24.gif', '24'),
  ZzzGifSpec('zzz.25', 'assets/themes/zzz/25.gif', '25'),
  ZzzGifSpec('zzz.26', 'assets/themes/zzz/26.gif', '26'),
  ZzzGifSpec('zzz.27', 'assets/themes/zzz/27.gif', '27'),
  ZzzGifSpec('zzz.28', 'assets/themes/zzz/28.gif', '28'),
  ZzzGifSpec('zzz.29', 'assets/themes/zzz/29.gif', '29'),
  ZzzGifSpec('zzz.2号', 'assets/themes/zzz/2号.gif', '2号'),
  ZzzGifSpec('zzz.30', 'assets/themes/zzz/30.gif', '30'),
  ZzzGifSpec('zzz.31', 'assets/themes/zzz/31.gif', '31'),
  ZzzGifSpec('zzz.32', 'assets/themes/zzz/32.gif', '32'),
  ZzzGifSpec('zzz.33', 'assets/themes/zzz/33.gif', '33'),
  ZzzGifSpec('zzz.34', 'assets/themes/zzz/34.gif', '34'),
  ZzzGifSpec('zzz.35', 'assets/themes/zzz/35.gif', '35'),
  ZzzGifSpec('zzz.36', 'assets/themes/zzz/36.gif', '36'),
  ZzzGifSpec('zzz.37', 'assets/themes/zzz/37.gif', '37'),
  ZzzGifSpec('zzz.38', 'assets/themes/zzz/38.gif', '38'),
  ZzzGifSpec('zzz.39', 'assets/themes/zzz/39.gif', '39'),
  ZzzGifSpec('zzz.3号', 'assets/themes/zzz/3号.gif', '3号'),
  ZzzGifSpec('zzz.40', 'assets/themes/zzz/40.gif', '40'),
  ZzzGifSpec('zzz.41', 'assets/themes/zzz/41.gif', '41'),
  ZzzGifSpec('zzz.42', 'assets/themes/zzz/42.gif', '42'),
  ZzzGifSpec('zzz.43', 'assets/themes/zzz/43.gif', '43'),
  ZzzGifSpec('zzz.4号', 'assets/themes/zzz/4号.gif', '4号'),
  ZzzGifSpec('zzz.5号', 'assets/themes/zzz/5号.gif', '5号'),
  ZzzGifSpec('zzz.6号', 'assets/themes/zzz/6号.gif', '6号'),
  ZzzGifSpec('zzz.7号', 'assets/themes/zzz/7号.gif', '7号'),
  ZzzGifSpec('zzz.8号', 'assets/themes/zzz/8号.gif', '8号'),
  ZzzGifSpec('zzz.9号', 'assets/themes/zzz/9号.gif', '9号'),
  ZzzGifSpec('zzz.冲击', 'assets/themes/zzz/冲击.gif', '冲击'),
  ZzzGifSpec('zzz.分身', 'assets/themes/zzz/分身.gif', '分身'),
  ZzzGifSpec('zzz.变换', 'assets/themes/zzz/变换.gif', '变换'),
  ZzzGifSpec('zzz.器械', 'assets/themes/zzz/器械.gif', '器械'),
  ZzzGifSpec('zzz.奇异', 'assets/themes/zzz/奇异.gif', '奇异'),
  ZzzGifSpec('zzz.恢复', 'assets/themes/zzz/恢复.gif', '恢复'),
  ZzzGifSpec('zzz.惩戒秩序', 'assets/themes/zzz/惩戒秩序.gif', '惩戒秩序'),
  ZzzGifSpec('zzz.护盾', 'assets/themes/zzz/护盾.gif', '护盾'),
  ZzzGifSpec('zzz.等离子', 'assets/themes/zzz/等离子.gif', '等离子'),
  ZzzGifSpec('zzz.重力', 'assets/themes/zzz/重力.gif', '重力'),
  ZzzGifSpec('zzz.雨天', 'assets/themes/zzz/雨天.gif', '雨天'),
  ZzzGifSpec('zzz.飞行', 'assets/themes/zzz/飞行.gif', '飞行'),
];

ZzzGifSpec zzzSpecFromSeed(int seed) {
  return zzzGifSpecs[seed.abs() % zzzGifSpecs.length];
}

/// A small corner GIF decoration for non-dashboard pages.
/// Places a subtle animated GIF in a corner with a gradient fade.
class ZzzCornerArt extends StatelessWidget {
  const ZzzCornerArt({
    super.key,
    required this.spec,
    this.size = 64,
    this.opacity = 0.35,
  });

  final ZzzGifSpec spec;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [zzzBgColor, Color(0x000A0A0F)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
