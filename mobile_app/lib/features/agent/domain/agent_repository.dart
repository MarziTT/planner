import 'parse_result.dart';
import 'schedule_request.dart';

abstract class AgentRepository {
  Future<ParseResult> parse(String text);
  Future<ParseResult> parseMulti(String text);
  Future<ParseResult> execute(ParseResult parsed);
  Future<void> schedule(ScheduleRequest request);
}
