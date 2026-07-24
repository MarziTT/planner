import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/local_cache_service.dart';
import '../../../core/network/api_client.dart';
import 'exercise_service.dart';
import 'auto_tracker.dart';
import 'trainer_service.dart';

/// Provider for ExerciseService — shared across exercise features.
final exerciseServiceProvider = Provider<ExerciseService>((ref) {
  final dio = ref.watch(apiClientProvider);
  final cache = ref.watch(localCacheProvider);
  return ExerciseService(dio: dio, cache: cache);
});

/// Provider for AutoTracker — depends on ExerciseService.
final autoTrackerProvider = Provider<AutoTracker>((ref) {
  final service = ref.watch(exerciseServiceProvider);
  return AutoTracker(service: service);
});

/// Provider for TrainerService — depends on ExerciseService.
final trainerServiceProvider = Provider<TrainerService>((ref) {
  final service = ref.watch(exerciseServiceProvider);
  return TrainerService(service: service);
});
