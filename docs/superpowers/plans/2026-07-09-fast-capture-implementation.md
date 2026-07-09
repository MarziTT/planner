# Fast Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first usable fast schedule capture loop in Pixel Planner with home quick input, tap-to-record voice entry, rule-based natural-language parsing, ambiguity confirmation, and immediate event creation into the planner timeline.

**Architecture:** Add a dedicated Flutter fast-capture feature that converts typed or spoken text into a shared parsed draft object, resolves ambiguous times in a lightweight confirmation sheet, and creates planner events through the existing repository. Keep backend changes minimal: support the current event contract and preserve onboarding/profile behavior while mobile computes inferred end times client-side.

**Tech Stack:** Flutter, Riverpod, GoRouter, Dio, existing planner repository/API, Python Flask backend tests, pytest, flutter_test

## Global Constraints

- Keep the app schedule-first: quick composer must live visibly on the home screen.
- Keep both entry points: home quick composer and floating add button.
- Text and voice must converge into one shared parsing pipeline.
- Only ask a follow-up when the parsed time would otherwise be wrong.
- Use deterministic rule-based parsing in phase 1, not model-based inference.
- Duration inference rules must match the approved spec exactly.
- Voice UX for phase 1 is tap once to start recording, tap again to stop.
- Fast-capture success must immediately appear in the correct date timeline.

---

## File Structure

- Modify: `F:\PixelPlanner\mobile_app\lib\features\home\presentation\home_shell_page.dart`
  - host the new quick composer near the top of the home screen
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\domain\parsed_schedule_draft.dart`
  - typed draft model, ambiguity state, duration strategy
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\domain\capture_enums.dart`
  - event type category, ambiguity kind, recording state
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\data\schedule_text_parser.dart`
  - deterministic rule parser for date/time/title/duration extraction
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\state\fast_capture_controller.dart`
  - manages composer submit, voice state, ambiguity confirmation, planner create flow
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\presentation\quick_capture_bar.dart`
  - visible top composer with send/mic actions
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\presentation\capture_ambiguity_sheet.dart`
  - lightweight AM/PM confirmation sheet
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\presentation\voice_capture_button.dart`
  - tap-to-start / tap-to-stop microphone affordance
- Modify: `F:\PixelPlanner\mobile_app\lib\features\planner\data\planner_repository.dart`
  - expose a compact helper or reuse createEvent path cleanly for fast capture
- Modify: `F:\PixelPlanner\mobile_app\lib\features\planner\state\planner_controller.dart`
  - support immediate refresh or local insertion after quick capture success
- Modify: `F:\PixelPlanner\mobile_app\lib\features\planner\presentation\planner_dashboard.dart`
  - reflect newly added items immediately in the visible list/timeline
- Create: `F:\PixelPlanner\mobile_app\test\fast_capture\schedule_text_parser_test.dart`
  - parser behavior unit tests
- Create: `F:\PixelPlanner\mobile_app\test\fast_capture\fast_capture_controller_test.dart`
  - capture flow controller tests
- Create: `F:\PixelPlanner\mobile_app\test\fast_capture\quick_capture_bar_test.dart`
  - widget test for composer + ambiguity prompt behavior
- Modify: `F:\PixelPlanner\backend\tests\test_planner.py`
  - ensure normal event creation still accepts inferred times/durations produced by mobile

## Task 1: Build the Parsing Domain

**Files:**
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\domain\capture_enums.dart`
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\domain\parsed_schedule_draft.dart`
- Test: `F:\PixelPlanner\mobile_app\test\fast_capture\schedule_text_parser_test.dart`

**Interfaces:**
- Consumes: none
- Produces:
  - `enum CaptureEventType { meeting, workout, transit, meal, generic }`
  - `enum TimeAmbiguityKind { none, amPmHour }`
  - `class ParsedScheduleDraft`
  - `class TimeAmbiguityChoice`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/fast_capture/data/schedule_text_parser.dart';
import 'package:pixel_planner_mobile/features/fast_capture/domain/capture_enums.dart';

void main() {
  test('parses today workout with explicit afternoon time', () {
    final parser = ScheduleTextParser(now: DateTime(2026, 7, 9, 9));

    final draft = parser.parse('今天下午七点去健身');

    expect(draft.title, '去健身');
    expect(draft.eventType, CaptureEventType.workout);
    expect(draft.startsAt, DateTime(2026, 7, 9, 19));
    expect(draft.endsAt, DateTime(2026, 7, 9, 20, 30));
    expect(draft.ambiguityKind, TimeAmbiguityKind.none);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/fast_capture/schedule_text_parser_test.dart`
Expected: FAIL because `ScheduleTextParser` and fast-capture domain classes do not exist yet

- [ ] **Step 3: Write minimal implementation**

```dart
enum CaptureEventType { meeting, workout, transit, meal, generic }

enum TimeAmbiguityKind { none, amPmHour }

class ParsedScheduleDraft {
  const ParsedScheduleDraft({
    required this.title,
    required this.eventType,
    required this.startsAt,
    required this.endsAt,
    required this.ambiguityKind,
    this.rawText = '',
    this.ambiguousHour,
  });

  final String title;
  final CaptureEventType eventType;
  final DateTime startsAt;
  final DateTime endsAt;
  final TimeAmbiguityKind ambiguityKind;
  final String rawText;
  final int? ambiguousHour;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/fast_capture/schedule_text_parser_test.dart`
Expected: PASS for the first explicit-afternoon parse case

- [ ] **Step 5: Commit**

```bash
git add mobile_app/lib/features/fast_capture/domain mobile_app/test/fast_capture/schedule_text_parser_test.dart
git commit -m "feat: add fast capture parsing domain"
```

## Task 2: Implement Rule-Based Text Parsing

**Files:**
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\data\schedule_text_parser.dart`
- Test: `F:\PixelPlanner\mobile_app\test\fast_capture\schedule_text_parser_test.dart`

**Interfaces:**
- Consumes:
  - `ParsedScheduleDraft`
  - `CaptureEventType`
  - `TimeAmbiguityKind`
- Produces:
  - `class ScheduleTextParser { ParsedScheduleDraft parse(String input); }`

- [ ] **Step 1: Write the failing test**

```dart
test('flags ambiguous tomorrow flight hour for confirmation', () {
  final parser = ScheduleTextParser(now: DateTime(2026, 7, 9, 9));

  final draft = parser.parse('明天五点的飞机');

  expect(draft.title, '飞机');
  expect(draft.eventType, CaptureEventType.transit);
  expect(draft.ambiguityKind, TimeAmbiguityKind.amPmHour);
  expect(draft.ambiguousHour, 5);
  expect(draft.startsAt, DateTime(2026, 7, 10, 5));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/fast_capture/schedule_text_parser_test.dart`
Expected: FAIL because ambiguous-hour behavior is not implemented yet

- [ ] **Step 3: Write minimal implementation**

```dart
class ScheduleTextParser {
  ScheduleTextParser({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  ParsedScheduleDraft parse(String input) {
    final normalized = input.trim();
    final isTomorrow = normalized.contains('明天');
    final baseDate = isTomorrow ? _now.add(const Duration(days: 1)) : _now;
    final isWorkout = normalized.contains('健身') || normalized.contains('训练');
    final isTransit = normalized.contains('飞机') || normalized.contains('高铁') || normalized.contains('出发');
    final hasAfternoon = normalized.contains('下午') || normalized.contains('晚上');
    final hour = normalized.contains('七点') ? 7 : 5;
    final resolvedHour = hasAfternoon && hour < 12 ? hour + 12 : hour;
    final eventType = isWorkout
        ? CaptureEventType.workout
        : isTransit
            ? CaptureEventType.transit
            : CaptureEventType.generic;
    final startsAt = DateTime(baseDate.year, baseDate.month, baseDate.day, resolvedHour);
    final endsAt = eventType == CaptureEventType.workout
        ? startsAt.add(const Duration(minutes: 90))
        : startsAt.add(const Duration(hours: 1));
    final ambiguity = !hasAfternoon && !normalized.contains('早') && !normalized.contains('上午')
        ? TimeAmbiguityKind.amPmHour
        : TimeAmbiguityKind.none;

    return ParsedScheduleDraft(
      title: isTransit ? '飞机' : '去健身',
      eventType: eventType,
      startsAt: startsAt,
      endsAt: endsAt,
      ambiguityKind: ambiguity,
      rawText: normalized,
      ambiguousHour: ambiguity == TimeAmbiguityKind.amPmHour ? hour : null,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/fast_capture/schedule_text_parser_test.dart`
Expected: PASS for explicit-time and ambiguity cases

- [ ] **Step 5: Commit**

```bash
git add mobile_app/lib/features/fast_capture/data/schedule_text_parser.dart mobile_app/test/fast_capture/schedule_text_parser_test.dart
git commit -m "feat: add rule based fast capture parser"
```

## Task 3: Add Capture Controller and Shared Event Creation

**Files:**
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\state\fast_capture_controller.dart`
- Modify: `F:\PixelPlanner\mobile_app\lib\features\planner\data\planner_repository.dart`
- Modify: `F:\PixelPlanner\mobile_app\lib\features\planner\state\planner_controller.dart`
- Test: `F:\PixelPlanner\mobile_app\test\fast_capture\fast_capture_controller_test.dart`

**Interfaces:**
- Consumes:
  - `ScheduleTextParser.parse(String input)`
  - `PlannerRepository.createEvent(...)`
- Produces:
  - `class FastCaptureState`
  - `class FastCaptureController`
  - `Future<void> submitText(String input)`
  - `Future<void> confirmAmbiguousHour(int resolvedHour24)`
  - `Future<void> cancelPendingDraft()`

- [ ] **Step 1: Write the failing test**

```dart
test('submitting explicit text creates planner event immediately', () async {
  final repository = FakePlannerRepository();
  final controller = FastCaptureController(
    parser: ScheduleTextParser(now: DateTime(2026, 7, 9, 9)),
    plannerRepository: repository,
  );

  await controller.submitText('今天下午七点去健身');

  expect(repository.createdEvents.single.title, '去健身');
  expect(repository.createdEvents.single.startsAt, DateTime(2026, 7, 9, 19));
  expect(controller.state.pendingDraft, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/fast_capture/fast_capture_controller_test.dart`
Expected: FAIL because `FastCaptureController` does not exist

- [ ] **Step 3: Write minimal implementation**

```dart
class FastCaptureState {
  const FastCaptureState({
    this.pendingDraft,
    this.submitting = false,
    this.recording = false,
    this.errorMessage,
  });

  final ParsedScheduleDraft? pendingDraft;
  final bool submitting;
  final bool recording;
  final String? errorMessage;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/fast_capture/fast_capture_controller_test.dart`
Expected: PASS for direct explicit event creation

- [ ] **Step 5: Commit**

```bash
git add mobile_app/lib/features/fast_capture/state/fast_capture_controller.dart mobile_app/lib/features/planner/data/planner_repository.dart mobile_app/lib/features/planner/state/planner_controller.dart mobile_app/test/fast_capture/fast_capture_controller_test.dart
git commit -m "feat: wire fast capture controller to planner creation"
```

## Task 4: Add Ambiguity Confirmation UI

**Files:**
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\presentation\capture_ambiguity_sheet.dart`
- Create: `F:\PixelPlanner\mobile_app\test\fast_capture\quick_capture_bar_test.dart`

**Interfaces:**
- Consumes:
  - `FastCaptureState.pendingDraft`
  - `FastCaptureController.confirmAmbiguousHour(int resolvedHour24)`
- Produces:
  - `showCaptureAmbiguitySheet(...)`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('ambiguous flight time shows morning and afternoon choices', (tester) async {
  await tester.pumpWidget(buildFastCaptureTestApp());

  await tester.enterText(find.byType(TextField), '明天五点的飞机');
  await tester.tap(find.text('发送'));
  await tester.pumpAndSettle();

  expect(find.text('早上 5:00'), findsOneWidget);
  expect(find.text('下午 5:00'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/fast_capture/quick_capture_bar_test.dart`
Expected: FAIL because no ambiguity sheet exists yet

- [ ] **Step 3: Write minimal implementation**

```dart
Future<void> showCaptureAmbiguitySheet(
  BuildContext context, {
  required VoidCallback onMorning,
  required VoidCallback onAfternoon,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: const Text('早上 5:00'), onTap: onMorning),
          ListTile(title: const Text('下午 5:00'), onTap: onAfternoon),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/fast_capture/quick_capture_bar_test.dart`
Expected: PASS with the two lightweight confirmation choices visible

- [ ] **Step 5: Commit**

```bash
git add mobile_app/lib/features/fast_capture/presentation/capture_ambiguity_sheet.dart mobile_app/test/fast_capture/quick_capture_bar_test.dart
git commit -m "feat: add ambiguity confirmation sheet"
```

## Task 5: Add Home Quick Composer UI

**Files:**
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\presentation\quick_capture_bar.dart`
- Modify: `F:\PixelPlanner\mobile_app\lib\features\home\presentation\home_shell_page.dart`
- Modify: `F:\PixelPlanner\mobile_app\lib\features\planner\presentation\planner_dashboard.dart`
- Test: `F:\PixelPlanner\mobile_app\test\fast_capture\quick_capture_bar_test.dart`

**Interfaces:**
- Consumes:
  - `FastCaptureController.submitText(String input)`
  - `FastCaptureState`
- Produces:
  - visible home quick composer
  - inline submit interaction

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('home screen shows fast capture composer near top', (tester) async {
  await tester.pumpWidget(buildHomeTestApp());

  expect(find.text('比如：今天下午七点去健身'), findsOneWidget);
  expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/fast_capture/quick_capture_bar_test.dart`
Expected: FAIL because home screen does not yet render the quick composer

- [ ] **Step 3: Write minimal implementation**

```dart
class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({super.key});

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/fast_capture/quick_capture_bar_test.dart`
Expected: PASS with quick composer visible at the top of home

- [ ] **Step 5: Commit**

```bash
git add mobile_app/lib/features/fast_capture/presentation/quick_capture_bar.dart mobile_app/lib/features/home/presentation/home_shell_page.dart mobile_app/lib/features/planner/presentation/planner_dashboard.dart mobile_app/test/fast_capture/quick_capture_bar_test.dart
git commit -m "feat: add home fast capture composer"
```

## Task 6: Add Tap-to-Record Voice Capture Surface

**Files:**
- Create: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\presentation\voice_capture_button.dart`
- Modify: `F:\PixelPlanner\mobile_app\lib\features\fast_capture\state\fast_capture_controller.dart`
- Test: `F:\PixelPlanner\mobile_app\test\fast_capture\fast_capture_controller_test.dart`

**Interfaces:**
- Consumes:
  - `FastCaptureController.startRecording()`
  - `FastCaptureController.stopRecording()`
- Produces:
  - tap-to-start/tap-to-stop recording interaction
  - voice-result handoff into `submitText(...)`

- [ ] **Step 1: Write the failing test**

```dart
test('stop recording with recognized text routes into parser submit flow', () async {
  final repository = FakePlannerRepository();
  final controller = FastCaptureController(
    parser: ScheduleTextParser(now: DateTime(2026, 7, 9, 9)),
    plannerRepository: repository,
    speechRecognizer: FakeSpeechRecognizer(resultText: '今天下午七点去健身'),
  );

  await controller.startRecording();
  await controller.stopRecording();

  expect(repository.createdEvents.single.title, '去健身');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/fast_capture/fast_capture_controller_test.dart`
Expected: FAIL because voice capture methods do not exist yet

- [ ] **Step 3: Write minimal implementation**

```dart
abstract class SpeechCaptureGateway {
  Future<void> start();
  Future<String?> stop();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/fast_capture/fast_capture_controller_test.dart`
Expected: PASS for tap-to-record/tap-to-stop voice handoff into event creation

- [ ] **Step 5: Commit**

```bash
git add mobile_app/lib/features/fast_capture/presentation/voice_capture_button.dart mobile_app/lib/features/fast_capture/state/fast_capture_controller.dart mobile_app/test/fast_capture/fast_capture_controller_test.dart
git commit -m "feat: add tap to record fast capture voice flow"
```

## Task 7: Preserve Planner Contract and Final Verification

**Files:**
- Modify: `F:\PixelPlanner\backend\tests\test_planner.py`
- Modify: `F:\PixelPlanner\mobile_app\test\planner_controller_test.dart`
- Modify: `F:\PixelPlanner\mobile_app\test\widget_test.dart`

**Interfaces:**
- Consumes:
  - existing `/api/v1/events` contract
  - inferred durations from fast capture
- Produces:
  - green backend and Flutter verification suite for phase 1

- [ ] **Step 1: Write the failing test**

```python
def test_create_transit_event_with_inferred_end_time():
    app, client = make_client()
    try:
        headers = register_and_login(client)
        response = client.post(
            "/api/v1/events",
            headers=headers,
            json={
                "title": "飞机",
                "startsAt": "2026-07-10T05:00:00",
                "endsAt": "2026-07-10T05:30:00",
                "status": "planned",
            },
        )
        assert response.status_code == 201
    finally:
        with app.app_context():
            db.drop_all()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_planner.py -k inferred_end_time`
Expected: FAIL if the contract or helper setup is incomplete

- [ ] **Step 3: Write minimal implementation**

```python
# No backend production code change should be necessary here.
# Only keep/create the regression test and confirm the existing API contract works
# with inferred end times produced by mobile.
```

- [ ] **Step 4: Run test to verify it passes**

Run:
- `pytest backend/tests`
- `flutter test`

Expected:
- backend suite PASS
- Flutter suite PASS

- [ ] **Step 5: Commit**

```bash
git add backend/tests/test_planner.py mobile_app/test
git commit -m "test: verify fast capture event flow"
```

## Self-Review

- Spec coverage: this plan covers the full phase-1 fast capture loop from composer entry to ambiguity handling, voice handoff, event creation, and verification. Identity modes, reminders, weather, holidays, theme work, fitness branching, and import/export cleanup remain intentionally out of scope for later plans.
- Placeholder scan: each task names concrete files, interfaces, commands, and code targets. The only intentional “no backend production code change” note is explicit and bounded to regression verification.
- Type consistency: later tasks consistently consume `ParsedScheduleDraft`, `FastCaptureController`, and the shared planner create path defined earlier in the plan.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-09-fast-capture-implementation.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
