# Task 3 Brief: Fast Capture Controller and Planner Creation

## Ownership

Only edit these files:

- `F:\PixelPlanner\mobile_app\lib\features\fast_capture\state\fast_capture_controller.dart`
- `F:\PixelPlanner\mobile_app\lib\features\planner\data\planner_repository.dart`
- `F:\PixelPlanner\mobile_app\lib\features\planner\state\planner_controller.dart`
- `F:\PixelPlanner\mobile_app\test\fast_capture\fast_capture_controller_test.dart`

Do not modify any other files.
You are not alone in the codebase. Do not revert others' changes.

## Goal

Convert parsed fast-capture text into actual planner event creation with a controller that either:

- creates immediately for explicit times, or
- holds a pending draft when AM/PM confirmation is required

## Required interfaces

- `class FastCaptureState`
- `class FastCaptureController`
- `Future<void> submitText(String input)`
- `Future<void> confirmAmbiguousHour(int resolvedHour24)`
- `Future<void> cancelPendingDraft()`

## Behavioral requirements

1. Submitting `今天下午七点去健身` creates a planner event immediately
2. Submitting `明天五点的飞机` does not create immediately; it stores a pending draft
3. Calling `confirmAmbiguousHour(17)` on that pending draft creates the event at `2026-07-10 17:00`
4. The controller should expose a small error string on failure
5. Keep the implementation small and dependency-light

## Repository/controller integration

- Reuse the existing planner repository create path if possible
- It is acceptable to add a tiny fast-capture-friendly create helper on `PlannerRepository`
- It is acceptable to add a local insert helper on `PlannerController` if needed later, but do not overbuild

## Test-first contract

1. Write failing controller tests first
2. Run `flutter test test/fast_capture/fast_capture_controller_test.dart` and confirm failure
3. Implement the minimum code to pass
4. Re-run the same focused test

## Return

- status: DONE / NEEDS_CONTEXT / BLOCKED
- files changed
- exact test command run
- pass/fail
- concerns
