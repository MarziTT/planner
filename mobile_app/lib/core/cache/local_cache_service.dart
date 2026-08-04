import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global provider — must be overridden in main() with a real instance.
final localCacheProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService.memory();
});

/// Key prefixes per domain to avoid collisions.
abstract class CacheKeys {
  static const plannerEvents = 'cache:planner:events';
  static const plannerTodos = 'cache:planner:todos';
  static const mealsToday = 'cache:meals:today';
  static const mealsHistory = 'cache:meals:history';
  static const mealsSummary = 'cache:meals:summary';
  static const exerciseToday = 'cache:exercise:today';
  static const exerciseHistory = 'cache:exercise:history';
  static const exerciseMode = 'cache:exercise:mode';
  static const tags = 'cache:tags';
  static const routineToday = 'cache:routine:today';
  static const dashboardOverview = 'cache:dashboard:overview';
  static const profile = 'cache:profile';
  static const settings = 'cache:settings';
}

/// Typed local cache on top of SharedPreferences.
///
/// Stores JSON-serialized snapshots keyed by domain.
/// Read path:  network → cache → return
/// Write path: return → cache (write-through)
@immutable
final class LocalCacheService {
  const LocalCacheService(this._prefs) : _memory = null;

  LocalCacheService.memory()
      : _prefs = null,
        _memory = <String, Object>{};

  final SharedPreferences? _prefs;
  final Map<String, Object>? _memory;

  String? _getString(String key) =>
      _prefs?.getString(key) ?? _memory?[key] as String?;

  int? _getInt(String key) => _prefs?.getInt(key) ?? _memory?[key] as int?;

  Future<void> _setString(String key, String value) async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(key, value);
    } else {
      _memory![key] = value;
    }
  }

  Future<void> _setInt(String key, int value) async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setInt(key, value);
    } else {
      _memory![key] = value;
    }
  }

  Future<void> _remove(String key) async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(key);
    } else {
      _memory!.remove(key);
    }
  }

  Iterable<String> _keys() => _prefs?.getKeys() ?? _memory!.keys;

  // ---------------------------------------------------------------------------
  // List API
  // ---------------------------------------------------------------------------

  /// Read a cached list, or null when absent.
  List<T>? readList<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    final raw = _getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .cast<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[LocalCache] decode error for "$key": $e');
      return null;
    }
  }

  /// Persist a list snapshot.
  Future<void> writeList<T>({
    required String key,
    required List<T> items,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    final json = jsonEncode(items.map(toJson).toList());
    await _setString(key, json);
  }

  // ---------------------------------------------------------------------------
  // Single-object API
  // ---------------------------------------------------------------------------

  T? readObject<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    final raw = _getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[LocalCache] decode error for "$key": $e');
      return null;
    }
  }

  Future<void> writeObject({
    required String key,
    required Map<String, dynamic> json,
  }) async {
    await _setString(key, jsonEncode(json));
  }

  // ---------------------------------------------------------------------------
  // Raw read (for simple values)
  // ---------------------------------------------------------------------------

  String? readRaw(String key) => _getString(key);

  Future<void> writeRaw(String key, String value) =>
      _setString(key, value);

  // ---------------------------------------------------------------------------
  // Eviction
  // ---------------------------------------------------------------------------

  Future<void> remove(String key) => _remove(key);

  /// Purge all cached data (called on logout).
  Future<void> clearAll() async {
    final allKeys = _keys().where((k) => k.startsWith('cache:')).toList();
    for (final key in allKeys) {
      await _remove(key);
    }
  }

  /// Timestamp of last cache write for a key (epoch seconds).
  int? lastCachedAt(String key) {
    final raw = _getInt('${key}:ts');
    return raw == 0 ? null : raw;
  }

  Future<void> _touchTimestamp(String key) async {
    await _setInt(
      '${key}:ts',
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }
}
