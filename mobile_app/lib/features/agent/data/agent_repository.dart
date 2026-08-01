import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/agent_repository.dart' as domain;
import '../domain/parse_result.dart';
import '../domain/schedule_request.dart';
import 'agent_api_client.dart';

class AgentRepositoryImpl implements domain.AgentRepository {
  AgentRepositoryImpl(this._apiClient);

  final AgentApiClient _apiClient;

  @override
  Future<ParseResult> parse(String text) => _apiClient.parse(text);

  @override
  Future<ParseResult> parseMulti(String text, {String? personaPreset}) =>
      _apiClient.parseMulti(text, personaPreset: personaPreset);

  @override
  Future<ParseResult> execute(ParseResult parsed) => _apiClient.execute(parsed);

  @override
  Future<void> schedule(ScheduleRequest request) =>
      _apiClient.schedule(request);
}

final agentApiClientProvider = Provider<AgentApiClient>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AgentApiClient(dio);
});

final agentRepositoryProvider = Provider<domain.AgentRepository>((ref) {
  final apiClient = ref.watch(agentApiClientProvider);
  return AgentRepositoryImpl(apiClient);
});
