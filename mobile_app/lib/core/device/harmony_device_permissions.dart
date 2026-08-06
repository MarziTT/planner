import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class HarmonyDevicePermissions {
  static const MethodChannel _channel =
      MethodChannel('pixelplanner/harmony_device_permissions');

  const HarmonyDevicePermissions();

  bool get isSupported => Platform.operatingSystem == 'ohos';

  Future<bool> requestMicrophonePermission() async {
    if (!isSupported) return true;
    return await _channel.invokeMethod<bool>('requestMicrophonePermission') ??
        false;
  }

  Future<DeviceLocation> getCurrentLocation() async {
    if (!isSupported) {
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.denied
          ? await Geolocator.requestPermission()
          : permission;
      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        throw const PermissionDeniedException('Location permission was denied');
      }
      final location = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      return DeviceLocation(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    }
    final value = await _channel.invokeMapMethod<String, Object?>(
      'getCurrentLocation',
    );
    if (value == null) {
      throw StateError('No location returned by HarmonyOS');
    }
    final latitude = value['latitude'];
    final longitude = value['longitude'];
    if (latitude is! num || longitude is! num) {
      throw StateError('Invalid HarmonyOS location response');
    }
    return DeviceLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }
}
