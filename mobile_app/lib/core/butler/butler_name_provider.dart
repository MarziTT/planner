import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/local_cache_service.dart';

/// 管家名字存储 key（非 cache: 前缀，登出时不清除 — 名字属于设备偏好）
const _butlerNameKey = 'butler:name';

/// 默认管家名字
const kDefaultButlerName = '贾维斯';

/// 管家名字全局 provider — 设置页可改，Agent 面板/FAB/问候语实时生效。
final butlerNameProvider =
    StateNotifierProvider<ButlerNameNotifier, String>((ref) {
  return ButlerNameNotifier(ref.watch(localCacheProvider));
});

class ButlerNameNotifier extends StateNotifier<String> {
  ButlerNameNotifier(this._cache)
      : super(_sanitize(_cache.readRaw(_butlerNameKey)));

  final LocalCacheService _cache;

  static String _sanitize(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? kDefaultButlerName : trimmed;
  }

  Future<void> setName(String name) async {
    final sanitized = _sanitize(name);
    state = sanitized;
    await _cache.writeRaw(_butlerNameKey, sanitized);
  }

  Future<void> reset() => setName(kDefaultButlerName);
}
