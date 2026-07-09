# Task 1+2 Repair Brief: Finish Fast Capture Parsing Slice

You are repairing and completing an in-progress fast-capture parsing slice.

## Ownership

Only edit these files:

- `F:\PixelPlanner\mobile_app\lib\features\fast_capture\domain\capture_enums.dart`
- `F:\PixelPlanner\mobile_app\lib\features\fast_capture\domain\parsed_schedule_draft.dart`
- `F:\PixelPlanner\mobile_app\lib\features\fast_capture\data\schedule_text_parser.dart`
- `F:\PixelPlanner\mobile_app\test\fast_capture\schedule_text_parser_test.dart`

Do not modify any other files.
You are not alone in the codebase. Do not revert others' changes.

## Current state

Partial files already exist.
Problems observed:

- `schedule_text_parser.dart` is still missing
- test import path is wrong (`package:mobile_app/...` instead of the app package)
- Chinese strings in the test file are mojibake and need to be normal UTF-8 Chinese text
- the tests should use `ScheduleTextParser(now: DateTime(2026, 7, 9, 9))`

## Required end state

1. `今天下午七点去健身`
   - title `去健身`
   - event type `CaptureEventType.workout`
   - starts `DateTime(2026, 7, 9, 19)`
   - ends `DateTime(2026, 7, 9, 20, 30)`
   - ambiguity `TimeAmbiguityKind.none`

2. `明天五点的飞机`
   - title `飞机`
   - event type `CaptureEventType.transit`
   - starts `DateTime(2026, 7, 10, 5)`
   - ends `DateTime(2026, 7, 10, 5, 30)`
   - ambiguity `TimeAmbiguityKind.amPmHour`
   - ambiguousHour `5`

## Constraints

- Deterministic rule parsing only
- Keep implementation small and explicit
- Duration rules in this slice:
  - workout = 90 minutes
  - transit = 30 minutes
  - unknown = 60 minutes
- Use the package import prefix already used elsewhere in the Flutter app: `package:pixel_planner_mobile/...`

## Required verification

Run:

`flutter test test/fast_capture/schedule_text_parser_test.dart`

Return:

- status: DONE / NEEDS_CONTEXT / BLOCKED
- files changed
- exact test command run
- whether it passed
- concerns
