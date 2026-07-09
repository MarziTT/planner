# Task 1+2 Brief: Fast Capture Parsing Foundation

You are implementing the first fast-capture slice for Pixel Planner.

## Scope

Own these files only:

- `F:\PixelPlanner\mobile_app\lib\features\fast_capture\domain\capture_enums.dart`
- `F:\PixelPlanner\mobile_app\lib\features\fast_capture\domain\parsed_schedule_draft.dart`
- `F:\PixelPlanner\mobile_app\lib\features\fast_capture\data\schedule_text_parser.dart`
- `F:\PixelPlanner\mobile_app\test\fast_capture\schedule_text_parser_test.dart`

Do not modify any other files.
You are not alone in the codebase. Do not revert edits made by others. Adjust to the existing code.

## Goal

Create the shared parsing domain and the first rule-based parser for fast schedule capture.

## Required behavior

1. Parse `今天下午七点去健身`
   - title: `去健身`
   - event type: workout
   - starts at `2026-07-09 19:00`
   - ends at `2026-07-09 20:30`
   - ambiguity kind: none

2. Parse `明天五点的飞机`
   - title: `飞机`
   - event type: transit
   - ambiguity kind: amPmHour
   - ambiguousHour: `5`
   - starts at `2026-07-10 05:00` as the draft base before confirmation

## Design constraints

- Use deterministic rule-based parsing only
- No AI/model parsing
- Keep the parser small and explicit
- Duration rules for this slice:
  - workout -> 90 minutes
  - transit -> 30 minutes
  - unknown -> 60 minutes
- Support only the exact phrases needed by these first tests plus obvious nearby helpers
- Keep output in a shared `ParsedScheduleDraft`

## Required types

- `enum CaptureEventType { meeting, workout, transit, meal, generic }`
- `enum TimeAmbiguityKind { none, amPmHour }`
- `class ParsedScheduleDraft`
- `class ScheduleTextParser { ParsedScheduleDraft parse(String input); }`

## Test-first contract

1. Write failing parser tests first
2. Run the focused test and confirm it fails
3. Implement the minimum code to pass
4. Re-run the focused test and report the result

## Report

When done, return:

- status: DONE / NEEDS_CONTEXT / BLOCKED
- files changed
- tests run and whether they passed
- any concerns
