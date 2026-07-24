import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monitors network reachability via [ConnectivityPlus].
///
/// Stream-based provider that emits `true` when the device has *any*
/// connectivity (mobile / wifi / ethernet / vpn), `false` otherwise.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});

/// Convenience provider that inverts [connectivityProvider].
final isOfflineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityProvider);
  return async.asData?.value == false;
});
