import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class HarmonySharedPreferences extends SharedPreferencesStorePlatform {
  static const MethodChannel _channel =
      MethodChannel('pixelplanner/harmony_secure_storage');

  static void register() {
    SharedPreferencesStorePlatform.instance = HarmonySharedPreferences();
  }

  @override
  Future<bool> clear() async {
    await _channel.invokeMethod<void>('preferencesClear', {
      'prefix': 'flutter.',
    });
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    final values = await _channel.invokeMapMethod<String, String>(
          'preferencesGetAll',
        ) ??
        const <String, String>{};
    return values.map((key, value) => MapEntry(key, jsonDecode(value) as Object));
  }

  @override
  Future<bool> remove(String key) async {
    await _channel.invokeMethod<void>('preferencesRemove', {'key': key});
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await _channel.invokeMethod<void>('preferencesSet', {
      'key': key,
      'value': jsonEncode(value),
    });
    return true;
  }
}
