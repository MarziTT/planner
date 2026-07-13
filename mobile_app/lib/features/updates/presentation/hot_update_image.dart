import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/resource_cache.dart';
import '../state/update_controller.dart';

class HotUpdateImage extends ConsumerWidget {
  const HotUpdateImage({
    super.key,
    required this.resourceId,
    required this.fallbackAsset,
    required this.fit,
    this.width,
    this.height,
    this.gaplessPlayback = true,
    this.errorBuilder,
  });

  final String resourceId;
  final String fallbackAsset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool gaplessPlayback;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      updateControllerProvider.select((state) => state.resourceRevision),
    );

    return FutureBuilder<File?>(
      future: ref.read(resourceCacheProvider).resolveFile(resourceId),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: gaplessPlayback,
            errorBuilder: errorBuilder,
          );
        }

        return Image.asset(
          fallbackAsset,
          fit: fit,
          width: width,
          height: height,
          gaplessPlayback: gaplessPlayback,
          errorBuilder: errorBuilder,
        );
      },
    );
  }
}
