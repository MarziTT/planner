import '../domain/capture_enums.dart';
import '../domain/parsed_schedule_draft.dart';

class ScheduleTextParser {
  ScheduleTextParser({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  /// Maps a parsed [CaptureEventType] to a human-readable tag name.
  /// Returns `null` for [CaptureEventType.generic] (no auto-tag).
  static const Map<CaptureEventType, String?> eventTypeToTagName = {
    CaptureEventType.workout: '健身',
    CaptureEventType.transit: '出行',
    CaptureEventType.meeting: '会议',
    CaptureEventType.meal: '饮食',
    CaptureEventType.entertainment: '休闲',
    CaptureEventType.study: '学习',
    CaptureEventType.life: '生活',
    CaptureEventType.social: '社交',
    CaptureEventType.generic: null,
  };

  ParsedScheduleDraft parse(String input) {
    final normalized = _normalize(input);
    final eventType = _looksLikeScheduleCommand(normalized)
        ? CaptureEventType.generic
        : _eventType(normalized);
    final relative = _relativeTime(normalized);
    final period = _period(normalized);
    final clock = _clock(normalized);
    final hasExplicitTime = relative != null || clock != null;

    final startsAt = relative ??
        _buildDateTime(
          dayOffset: _dayOffset(normalized),
          hour: _resolveHour(
            period: period,
            hour: clock?.hour,
            eventType: eventType,
          ),
          minute: clock?.minute ?? 0,
        );
    final endsAt = startsAt.add(_durationFor(eventType));
    final title = _title(normalized);
    final ambiguousHour =
        _isAmbiguousHour(period, clock?.hour) ? clock!.hour : null;
    final missingTime = !hasExplicitTime;
    final hasLocationOrPerson = _hasLocationOrPerson(normalized);

    final confidence = _calculateConfidence(
      hasExplicitTime: hasExplicitTime,
      hasTitle: title.isNotEmpty,
      eventType: eventType,
      hasLocationOrPerson: hasLocationOrPerson,
    );

    return ParsedScheduleDraft(
      title: title.isEmpty ? '未命名行程' : title,
      eventType: eventType,
      startsAt: startsAt,
      endsAt: endsAt,
      ambiguityKind: ambiguousHour != null
          ? TimeAmbiguityKind.amPmHour
          : missingTime
              ? TimeAmbiguityKind.missingTime
              : TimeAmbiguityKind.none,
      ambiguousHour: ambiguousHour,
      suggestedPeriod:
          missingTime ? _suggestedPeriodFor(period, eventType) : null,
      confidence: confidence,
    );
  }

  double _calculateConfidence({
    required bool hasExplicitTime,
    required bool hasTitle,
    required CaptureEventType eventType,
    required bool hasLocationOrPerson,
  }) {
    double score = 0.2;
    if (hasExplicitTime) score += 0.3;
    if (hasTitle) score += 0.2;
    if (eventType != CaptureEventType.generic) score += 0.15;
    if (hasLocationOrPerson) score += 0.2;
    return score.clamp(0.0, 1.0);
  }

  bool _hasLocationOrPerson(String input) {
    return RegExp(r'(在|去|到|跟|和|与|约)(.+?)(?:[，,。\s]|$)').hasMatch(input) ||
        RegExp(r'(?:餐厅|咖啡|图书馆|健身房|商场|公园|电影院|KTV|学校|公司|家|广场|中心|大厦)')
            .hasMatch(input) ||
        RegExp(r'[和跟与约][\u4e00-\u9fa5]{1,3}(?:一起|吃饭|玩|去|见|聚|聊)')
            .hasMatch(input);
  }

  String _normalize(String input) {
    return input
        .trim()
        .replaceAll('：', ':')
        .replaceAll('钟', '点')
        .replaceAll('個', '个')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  int _dayOffset(String input) {
    if (input.contains('大后天')) {
      return 3;
    }
    if (input.contains('后天')) {
      return 2;
    }
    if (input.contains('明天') || input.contains('明早')) {
      return 1;
    }

    final weekdayOffset = _weekdayOffset(input);
    if (weekdayOffset != null) {
      return weekdayOffset;
    }
    return 0;
  }

  int? _weekdayOffset(String input) {
    final match = RegExp(r'(下周|周|星期)([一二三四五六日天])').firstMatch(input);
    if (match == null) {
      if (input.contains('周末')) {
        return _daysUntilWeekday(6, forceNextWeek: false);
      }
      return null;
    }

    final prefix = match.group(1)!;
    final weekday = _weekdayNumber(match.group(2)!);
    return _daysUntilWeekday(weekday, forceNextWeek: prefix == '下周');
  }

  int _daysUntilWeekday(int weekday, {required bool forceNextWeek}) {
    final current = _now.weekday;
    var offset = weekday - current;
    if (forceNextWeek) {
      while (offset <= 0) {
        offset += 7;
      }
      return offset;
    }
    if (offset < 0) {
      offset += 7;
    }
    return offset;
  }

  int _weekdayNumber(String token) {
    const map = {
      '一': DateTime.monday,
      '二': DateTime.tuesday,
      '三': DateTime.wednesday,
      '四': DateTime.thursday,
      '五': DateTime.friday,
      '六': DateTime.saturday,
      '日': DateTime.sunday,
      '天': DateTime.sunday,
    };
    return map[token] ?? DateTime.monday;
  }

  String? _period(String input) {
    const periods = [
      '凌晨',
      '明早',
      '早上',
      '上午',
      '中午',
      '下午',
      '傍晚',
      '晚上',
      '今晚',
    ];
    for (final period in periods) {
      if (input.contains(period)) {
        return period;
      }
    }
    return null;
  }

  DateTime? _relativeTime(String input) {
    if (input.contains('一会儿') ||
        input.contains('待会儿') ||
        input.contains('等会儿')) {
      return _now.add(const Duration(minutes: 30));
    }
    if (input.contains('半小时后')) {
      return _now.add(const Duration(minutes: 30));
    }

    final minuteMatch =
        RegExp(r'([0-9]{1,2}|[一二三四五六七八九十两]+)分钟后').firstMatch(input);
    if (minuteMatch != null) {
      return _now
          .add(Duration(minutes: _parseNumberWord(minuteMatch.group(1)!)));
    }

    final hourMatch =
        RegExp(r'([0-9]{1,2}|[一二三四五六七八九十两]+)小时后').firstMatch(input);
    if (hourMatch != null) {
      return _now.add(Duration(hours: _parseNumberWord(hourMatch.group(1)!)));
    }
    return null;
  }

  _ClockToken? _clock(String input) {
    final colonMatch = RegExp(
      r'(?:凌晨|明早|早上|上午|中午|下午|傍晚|晚上|今晚)?([0-9]{1,2}):([0-9]{1,2})',
    ).firstMatch(input);
    if (colonMatch != null) {
      return _ClockToken(
        hour: int.parse(colonMatch.group(1)!),
        minute: int.parse(colonMatch.group(2)!),
      );
    }

    final dotMatch = RegExp(
      r'(?:凌晨|明早|早上|上午|中午|下午|傍晚|晚上|今晚)?([0-9]{1,2}|[一二三四五六七八九十两]+)点(?:(半)|([0-9]{1,2})分?|([一二三四五六七八九十两]+)分?)?',
    ).firstMatch(input);
    if (dotMatch == null) {
      return null;
    }

    final hour = _parseHour(dotMatch.group(1)!);
    final minute = dotMatch.group(2) != null
        ? 30
        : dotMatch.group(3) != null
            ? int.parse(dotMatch.group(3)!)
            : dotMatch.group(4) != null
                ? _parseMinuteWord(dotMatch.group(4)!)
                : 0;
    return _ClockToken(hour: hour, minute: minute);
  }

  bool _isAmbiguousHour(String? period, int? hour) {
    if (period != null || hour == null) {
      return false;
    }
    return hour > 0 && hour < 12;
  }

  int _resolveHour({
    required String? period,
    required int? hour,
    required CaptureEventType eventType,
  }) {
    if (hour == null || hour == 0) {
      return _defaultHour(period: period, eventType: eventType);
    }

    if (period == null) {
      return hour;
    }
    if (period == '中午') {
      if (hour == 12) return 12;
      return hour == 0 ? 12 : hour + 12;
    }
    if (period == '凌晨' || period == '明早' || period == '早上' || period == '上午') {
      return hour == 12 ? 0 : hour;
    }
    if (period == '下午' || period == '傍晚' || period == '晚上' || period == '今晚') {
      return hour == 12 ? 12 : hour + 12;
    }
    return hour;
  }

  int _defaultHour({
    required String? period,
    required CaptureEventType eventType,
  }) {
    if (period == '凌晨') return 1;
    if (period == '明早' || period == '早上' || period == '上午') return 9;
    if (period == '中午') return 12;
    if (period == '下午') return 15;
    if (period == '傍晚') return 18;
    if (period == '晚上' || period == '今晚') return 19;

    switch (eventType) {
      case CaptureEventType.workout:
        return 19;
      case CaptureEventType.transit:
        return 9;
      case CaptureEventType.meeting:
      case CaptureEventType.study:
        return 10;
      case CaptureEventType.meal:
        return 12;
      case CaptureEventType.entertainment:
        return 20;
      case CaptureEventType.life:
        return 10;
      case CaptureEventType.social:
        return 18;
      case CaptureEventType.generic:
        return 9;
    }
  }

  TimePeriod _suggestedPeriodFor(String? period, CaptureEventType eventType) {
    if (period == '明早' || period == '早上' || period == '上午') {
      return TimePeriod.morning;
    }
    if (period == '下午' || period == '傍晚') {
      return TimePeriod.afternoon;
    }
    if (period == '晚上' || period == '今晚') {
      return TimePeriod.evening;
    }
    if (period == '中午') {
      return TimePeriod.afternoon;
    }

    switch (eventType) {
      case CaptureEventType.workout:
        return TimePeriod.evening;
      case CaptureEventType.meal:
        return TimePeriod.afternoon;
      case CaptureEventType.meeting:
      case CaptureEventType.study:
      case CaptureEventType.transit:
      case CaptureEventType.life:
      case CaptureEventType.generic:
        return TimePeriod.morning;
      case CaptureEventType.entertainment:
      case CaptureEventType.social:
        return TimePeriod.evening;
    }
  }

  DateTime _buildDateTime({
    required int dayOffset,
    required int hour,
    required int minute,
  }) {
    final baseDate = DateTime(_now.year, _now.month, _now.day)
        .add(Duration(days: dayOffset));
    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  bool _looksLikeScheduleCommand(String input) {
    const markers = [
      '日程',
      '行程',
      '安排',
      '计划',
      '预约',
    ];
    return markers.any(input.contains);
  }

  CaptureEventType _eventType(String input) {
    if (input.contains('健身') ||
        input.contains('训练') ||
        input.contains('跑步') ||
        input.contains('游泳') ||
        input.contains('力量') ||
        input.contains('锻炼') ||
        input.contains('瑜伽')) {
      return CaptureEventType.workout;
    }
    if (input.contains('飞机') ||
        input.contains('高铁') ||
        input.contains('火车') ||
        input.contains('出发') ||
        input.contains('赶车') ||
        input.contains('航班')) {
      return CaptureEventType.transit;
    }
    if (input.contains('开会') ||
        input.contains('会议') ||
        input.contains('面试') ||
        input.contains('上课') ||
        input.contains('答辩')) {
      return CaptureEventType.meeting;
    }
    if (input.contains('吃饭') ||
        input.contains('午休') ||
        input.contains('晚饭') ||
        input.contains('早餐')) {
      return CaptureEventType.meal;
    }
    if (input.contains('追剧') ||
        input.contains('看片') ||
        input.contains('打游戏') ||
        input.contains('刷番')) {
      return CaptureEventType.entertainment;
    }
    if (input.contains('看书') ||
        input.contains('复习') ||
        input.contains('备考') ||
        input.contains('听课')) {
      return CaptureEventType.study;
    }
    if (input.contains('买菜') ||
        input.contains('做饭') ||
        input.contains('打扫') ||
        input.contains('洗衣')) {
      return CaptureEventType.life;
    }
    if (input.contains('聚会') ||
        input.contains('约饭') ||
        input.contains('逛街') ||
        input.contains('桌游')) {
      return CaptureEventType.social;
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
        return const Duration(hours: 1);
      case CaptureEventType.meal:
        return const Duration(minutes: 75);
      case CaptureEventType.entertainment:
        return const Duration(hours: 2);
      case CaptureEventType.study:
        return const Duration(hours: 1);
      case CaptureEventType.life:
        return const Duration(minutes: 60);
      case CaptureEventType.social:
        return const Duration(hours: 2);
      case CaptureEventType.generic:
        return const Duration(hours: 1);
    }
  }

  String _title(String input) {
    var title = input;
    title = title.replaceFirst(
        RegExp(
            r'^(今天|明天|后天|大后天|明早|今晚|周末|下周[一二三四五六日天]|周[一二三四五六日天]|星期[一二三四五六日天])'),
        '');
    title = title.replaceFirst(RegExp(r'^(凌晨|早上|上午|中午|下午|傍晚|晚上|今晚|明早)'), '');
    title = title.replaceFirst(
        RegExp(
            r'^([0-9]{1,2}:[0-9]{1,2}|[0-9]{1,2}|[一二三四五六七八九十两]+)点(?:(半)|([0-9]{1,2})分?|([一二三四五六七八九十两]+)分?)?'),
        '');
    title = title.replaceFirst(
        RegExp(
            r'^(一会儿|待会儿|等会儿|半小时后|[0-9一二三四五六七八九十两]+分钟后|[0-9一二三四五六七八九十两]+小时后)'),
        '');
    title = title.replaceFirst(
        RegExp(r'^(的|要|去|得|安排|记得|帮我|提醒我|记录日程|记录行程|日程|行程|计划|预约)'), '');
    title = title.trim();
    return title.isEmpty ? input.trim() : title;
  }

  int _parseHour(String token) => _parseNumberWord(token);

  int _parseNumberWord(String token) {
    final numeric = int.tryParse(token);
    if (numeric != null) {
      return numeric;
    }

    const map = {
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
      '十一': 11,
      '十二': 12,
    };
    return map[token] ?? 0;
  }

  int _parseMinuteWord(String token) {
    const minuteMap = {
      '十': 10,
      '十五': 15,
      '二十': 20,
      '二十五': 25,
      '三十': 30,
      '三十五': 35,
      '四十': 40,
      '四十五': 45,
      '五十': 50,
      '五十五': 55,
    };
    return minuteMap[token] ?? 0;
  }
}

class _ClockToken {
  const _ClockToken({required this.hour, required this.minute});

  final int hour;
  final int minute;
}
