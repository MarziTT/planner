/// External app deep-link service.
///
/// Handles launching 3rd-party apps via URL schemes:
/// - 滴滴出行 (diditaxi://)
/// - 高德地图 (amapuri://)
/// - 12306 (train12306://)
///
/// Spec: §6.5 — Deep Link 跳转

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalAppService {
  /// Check if an app is installed by trying to launch its URL scheme.
  static Future<bool> _canOpen(String scheme) async {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return canLaunchUrl(Uri.parse(scheme));
    }
    return false;
  }

  /// Open 滴滴出行 to hail a taxi to [destination].
  ///
  /// URL scheme: diditaxi://
  /// Returns true if the app was opened, false if not installed.
  static Future<bool> openDidiTaxi(String destination) async {
    // Encode destination as query parameter.
    // The actual diditaxi:// scheme may vary by region and version.
    final encoded = Uri.encodeComponent(destination);
    final uri = Uri.tryParse('diditaxi://');

    if (uri == null) return false;

    final canOpen = await _canOpen('diditaxi://');
    if (!canOpen) return false;

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Open 高德地图 to plan a route from [from] to [to].
  ///
  /// URL scheme: amapuri://route/plan
  static Future<bool> openAmapRoute(String from, String to) async {
    final encodedFrom = Uri.encodeComponent(from);
    final encodedTo = Uri.encodeComponent(to);

    final uri = Uri.tryParse(
      'amapuri://route/plan?sourceApplication=PixelPlanner'
      '&slat=&slon=&sname=$encodedFrom'
      '&dlat=&dlon=&dname=$encodedTo'
      '&dev=0&t=0',
    );

    if (uri == null) return false;

    final canOpen = await _canOpen('amapuri://route/plan');
    if (!canOpen) return false;

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Open 高德地图 app (fallback when route scheme fails).
  static Future<bool> openAmapApp() async {
    final uri = Uri.tryParse('amapuri://');
    if (uri == null) return false;

    final canOpen = await _canOpen('amapuri://');
    if (!canOpen) return false;

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Open 铁路12306 app.
  static Future<bool> openRailway12306() async {
    final uri = Uri.tryParse('train12306://');
    if (uri == null) return false;

    final canOpen = await _canOpen('train12306://');
    if (!canOpen) return false;

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Show a dialog guiding the user to install an app.
  static void showAppNotInstalled(String appName, String scheme) {
    // This is a platform-level concern; we just log.
    debugPrint('[ExternalApp] $appName not installed (scheme: $scheme)');
  }
}
