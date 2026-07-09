import 'capture_enums.dart';

class ParsedScheduleDraft {
  const ParsedScheduleDraft({
    required this.title,
    required this.eventType,
    required this.startsAt,
    required this.endsAt,
    required this.ambiguityKind,
    this.ambiguousHour,
  });

  final String title;
  final CaptureEventType eventType;
  final DateTime startsAt;
  final DateTime endsAt;
  final TimeAmbiguityKind ambiguityKind;
  final int? ambiguousHour;
}
