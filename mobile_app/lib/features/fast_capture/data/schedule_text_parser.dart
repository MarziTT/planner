import '../domain/capture_enums.dart';
import '../domain/parsed_schedule_draft.dart';

class ScheduleTextParser {
  ScheduleTextParser({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  ParsedScheduleDraft parse(String input) {
    final normalized = input.trim();
    final dayOffset = _dayOffset(normalized);
    final period = _period(normalized);
    final hourToken = _hourToken(normalized);
    final ambiguousHour = _isAmbiguousHour(period, hourToken) ? hourToken : null;
    final resolvedHour = _resolveHour(period, hourToken);
    final startsAt = _buildDateTime(dayOffset, resolvedHour);
    final eventType = _eventType(normalized);
    final endsAt = startsAt.add(_durationFor(eventType));

    return ParsedScheduleDraft(
      title: _title(normalized),
      eventType: eventType,
      startsAt: startsAt,
      endsAt: endsAt,
      ambiguityKind:
          ambiguousHour == null ? TimeAmbiguityKind.none : TimeAmbiguityKind.amPmHour,
      ambiguousHour: ambiguousHour,
    );
  }

  int _dayOffset(String input) {
    if (input.contains('\u660e\u5929')) {
      return 1;
    }
    return 0;
  }

  String? _period(String input) {
    const periods = [
      '\u51cc\u6668',
      '\u65e9\u4e0a',
      '\u4e0a\u5348',
      '\u4e2d\u5348',
      '\u4e0b\u5348',
      '\u665a\u4e0a',
    ];
    for (final period in periods) {
      if (input.contains(period)) {
        return period;
      }
    }
    return null;
  }

  int _hourToken(String input) {
    final match = RegExp(
      '(?:\u51cc\u6668|\u65e9\u4e0a|\u4e0a\u5348|\u4e2d\u5348|\u4e0b\u5348|\u665a\u4e0a)?([0-9]{1,2}|[\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u4e24]+)\u70b9',
    ).firstMatch(input);
    if (match == null) {
      return 0;
    }
    return _parseHour(match.group(1)!);
  }

  bool _isAmbiguousHour(String? period, int hour) {
    return period == null && hour > 0 && hour < 12;
  }

  int _resolveHour(String? period, int hour) {
    if (period == null) {
      return hour;
    }
    if (period == '\u4e2d\u5348') {
      if (hour == 12) return 12;
      return hour == 0 ? 12 : hour + 12;
    }
    if (period == '\u51cc\u6668' || period == '\u65e9\u4e0a' || period == '\u4e0a\u5348') {
      return hour == 12 ? 0 : hour;
    }
    if (period == '\u4e0b\u5348' || period == '\u665a\u4e0a') {
      return hour == 12 ? 12 : hour + 12;
    }
    return hour;
  }

  DateTime _buildDateTime(int dayOffset, int hour) {
    final baseDate =
        DateTime(_now.year, _now.month, _now.day).add(Duration(days: dayOffset));
    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour);
  }

  CaptureEventType _eventType(String input) {
    if (input.contains('\u5065\u8eab') ||
        input.contains('\u8bad\u7ec3') ||
        input.contains('\u8dd1\u6b65') ||
        input.contains('\u6e38\u6cf3')) {
      return CaptureEventType.workout;
    }
    if (input.contains('\u98de\u673a') ||
        input.contains('\u9ad8\u94c1') ||
        input.contains('\u51fa\u53d1') ||
        input.contains('\u8d76\u8f66')) {
      return CaptureEventType.transit;
    }
    if (input.contains('\u5f00\u4f1a') ||
        input.contains('\u4f1a\u8bae') ||
        input.contains('\u9762\u8bd5') ||
        input.contains('\u4e0a\u8bfe')) {
      return CaptureEventType.meeting;
    }
    if (input.contains('\u5403\u996d') ||
        input.contains('\u7ea6\u996d') ||
        input.contains('\u5348\u4f11')) {
      return CaptureEventType.meal;
    }
    return CaptureEventType.generic;
  }

  Duration _durationFor(CaptureEventType eventType) {
    switch (eventType) {
      case CaptureEventType.workout:
        return const Duration(minutes: 90);
      case CaptureEventType.transit:
        return const Duration(minutes: 30);
      case CaptureEventType.meeting:
      case CaptureEventType.meal:
      case CaptureEventType.generic:
        return const Duration(hours: 1);
    }
  }

  String _title(String input) {
    final timePattern = RegExp(
      '^(?:\u4eca\u5929|\u660e\u5929)?(?:\u51cc\u6668|\u65e9\u4e0a|\u4e0a\u5348|\u4e2d\u5348|\u4e0b\u5348|\u665a\u4e0a)?(?:[0-9]{1,2}|[\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u4e24]+)\u70b9',
    );
    final match = timePattern.firstMatch(input);
    if (match == null) {
      return input;
    }

    var title = input.substring(match.end);
    if (title.startsWith('\u7684')) {
      title = title.substring(1);
    }
    return title.trim();
  }

  int _parseHour(String token) {
    final numeric = int.tryParse(token);
    if (numeric != null) {
      return numeric;
    }

    const hourMap = {
      '\u4e00': 1,
      '\u4e8c': 2,
      '\u4e24': 2,
      '\u4e09': 3,
      '\u56db': 4,
      '\u4e94': 5,
      '\u516d': 6,
      '\u4e03': 7,
      '\u516b': 8,
      '\u4e5d': 9,
      '\u5341': 10,
      '\u5341\u4e00': 11,
      '\u5341\u4e8c': 12,
    };
    return hourMap[token] ?? 0;
  }
}
