import 'parse_result.dart';
import 'schedule_request.dart';

abstract class AgentRepository {
  Future<ParseResult> parse(String text);
  Future<void> schedule(ScheduleRequest request);
}
