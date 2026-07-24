import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/scheduler_models.dart';

/// Repository for the scheduler API endpoints.
class SchedulerRepository {
  const SchedulerRepository({required this.dio});

  final Dio dio;

  /// POST /scheduler/suggest — get optimal time suggestions.
  Future<ScheduleSuggestion> suggest({
    required String date,
    int durationMinutes = 60,
    String? preferredPeriod,
  }) async {
    final body = <String, dynamic>{
      'date': date,
      'duration_minutes': durationMinutes,
    };
    if (preferredPeriod != null) {
      body['preferred_period'] = preferredPeriod;
    }

    final response = await dio.post('/scheduler/suggest', data: body);
    final parsed = ApiResponse.raw(response, ScheduleSuggestion.fromJson);
    if (!parsed.isSuccess || parsed.data == null) {
      throw Exception(parsed.message ?? 'Failed to get suggestions');
    }
    return parsed.data!;
  }

  /// POST /scheduler/conflicts — check for time conflicts.
  Future<ConflictCheck> checkConflicts({
    required String startsAt,
    required String endsAt,
    int? excludeEventId,
  }) async {
    final body = <String, dynamic>{
      'starts_at': startsAt,
      'ends_at': endsAt,
    };
    if (excludeEventId != null) {
      body['exclude_event_id'] = excludeEventId;
    }

    final response = await dio.post('/scheduler/conflicts', data: body);
    final parsed = ApiResponse.raw(response, ConflictCheck.fromJson);
    if (!parsed.isSuccess || parsed.data == null) {
      throw Exception(parsed.message ?? 'Failed to check conflicts');
    }
    return parsed.data!;
  }
}

/// Riverpod provider for SchedulerRepository.
final schedulerRepositoryProvider = Provider<SchedulerRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return SchedulerRepository(dio: dio);
});
