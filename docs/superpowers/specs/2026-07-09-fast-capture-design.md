# Pixel Planner Fast Capture Design

## Summary

Phase 1 re-centers Pixel Planner around one core promise: users can add a schedule item in a sentence or by voice with minimal friction, and the event lands in the right day and time slot immediately.

This phase only covers the fast-capture loop. It does not yet redesign identity modes, fitness visibility rules, weather reminders, holiday markers, or notification-surface polish beyond what is needed to support the new event creation flow.

## Goal

Build a dual-entry fast schedule capture experience that supports:

- always-visible home quick input
- floating action button for full add flow
- one-sentence text parsing
- tap-to-start / tap-to-stop voice capture
- lightweight ambiguity confirmation for unclear AM/PM times
- default duration guessing by event type
- immediate insertion into the correct date timeline

## Product Principles

1. Fast first: common schedule capture should take one sentence and one confirmation at most.
2. Low interruption: only ask follow-up questions when the schedule would otherwise be wrong.
3. Same brain for text and voice: voice capture becomes text, then goes through the same parsing and confirmation flow.
4. Predictable over magical: phase 1 prefers rule-based parsing that is debuggable and stable.
5. Instant visual payoff: successful capture must show up on the home timeline and the target day immediately.

## User Experience

### Entry Points

The app exposes two creation entry points at the same time:

1. Home quick composer
   - A persistent input bar near the top of the home screen
   - Placeholder example such as `比如：今天下午七点去健身`
   - Send action submits text directly into fast parsing
   - Adjacent microphone button starts voice capture

2. Floating add button
   - Opens a richer add flow for users who want to edit more details
   - Can prefill title/date/time from parsed sentence results
   - Remains available even after quick composer ships

### Text Capture Flow

1. User enters a natural sentence
2. Parser extracts:
   - target date
   - target time
   - title / intent
   - event type category
   - inferred duration strategy
3. If time is ambiguous, show a lightweight confirmation sheet with two choices
4. On confirmation, create the event
5. Home timeline refreshes and scrolls to reveal the item when practical

### Voice Capture Flow

1. User taps microphone once to start recording
2. UI switches into recording state
3. User taps again to stop
4. Recognized text is placed into the same fast-capture pipeline as typed input
5. If ASR returns empty or low-confidence text, show a compact retry message

### Ambiguity Confirmation

Phase 1 only asks follow-up questions for time ambiguity that would produce the wrong schedule.

Example:
- Input: `明天五点的飞机`
- Confirmation:
  - `早上 5:00`
  - `下午 5:00`

This confirmation should feel like a tiny decision chip sheet, not a full modal form.

## Parsing Rules

Phase 1 uses deterministic rules rather than model inference.

### Date extraction

Support first:

- 今天
- 明天
- 后天
- 周一到周日
- 下周一到下周日
- explicit month/day style when easy to parse

### Time extraction

Support first:

- 上午 / 早上 / 中午 / 下午 / 晚上
- `7点`, `7点半`, `10:30`, `19:00`
- `明早五点`, `下午七点`

### Ambiguity policy

Ask for confirmation when the user gives an hour without a clear daypart and the event cannot be safely inferred.

Do not ask when the text already carries a daypart:

- `下午七点去健身`
- `明早五点的飞机`

### Duration inference

Phase 1 duration guesses:

- `开会 / 会议 / 面试 / 上课` -> 1 hour
- `健身 / 训练 / 跑步 / 游泳` -> 1.5 hours
- `飞机 / 高铁 / 出发 / 赶车` -> start-time only emphasis, end time may default to start plus 30 minutes internally or remain visually minimal depending on existing event model constraints
- `吃饭 / 约饭 / 午休` -> 1 hour
- unknown events -> 1 hour

The parser should also return whether the event is “transit-like” so the UI can present it differently later if needed.

## Data and Architecture

### Mobile app

Add a dedicated fast-capture feature in Flutter:

- parsing service for sentence-to-draft conversion
- capture controller for composer state, recording state, ambiguity prompts, and submit lifecycle
- quick composer widget on home screen
- ambiguity confirmation UI
- shared event creation path that calls planner repository

Text and voice must converge into the same `ParsedScheduleDraft` structure before event creation.

### Backend

Phase 1 does not require server-side natural language parsing.

Backend only needs to continue accepting normal event create requests. If current event schema requires an end time, mobile computes one from the inferred duration rules before submission.

### Voice

Phase 1 can keep ASR as a thin layer:

- preferred: client records audio and uses current voice pipeline if available
- acceptable fallback: mocked or partial voice input while the UI flow is built, but the visible interaction contract must match final behavior

Because the product promise includes voice, this flow cannot remain a dead button after phase 1 completes.

## Home Screen Changes

The home screen should become schedule-first:

- top summary remains compact
- quick composer moves near the top and feels primary
- timeline below becomes the main surface
- FAB remains visible for manual full add

Quick composer should not be hidden behind tabs or secondary menus.

## Error Handling

- Empty input: ignore submit and keep focus
- Unrecognized date/time: route into the richer add flow with extracted title preserved
- Ambiguous hour: show the two-choice confirmation
- Voice permission denied: show one-step inline explanation and fallback to text
- Network failure on create: preserve the captured sentence so the user can retry without retyping

## Testing Strategy

### Flutter

- parser unit tests for date extraction, time extraction, ambiguity detection, duration guessing
- controller tests for submit, confirmation, failure recovery, voice state transitions
- widget tests for home quick composer and ambiguity sheet

### Backend

- no new backend parsing tests needed for phase 1
- keep existing planner event create tests passing

## Out of Scope

These are intentionally deferred to later phases:

- identity questionnaire redesign
- work-mode / student-mode / household-mode scheduling behavior
- weather integration
- holiday markers
- notification drawer / lock-screen experience
- theme overhaul and Kamen Rider GIF integration
- fitness module conditional display redesign
- import/export removal cleanup

## Recommended Phase Order After This

1. Fast capture core
2. Identity questionnaire and mode-aware home logic
3. Reminder intelligence: weather, holidays, upcoming notifications
4. Fitness conditional surfacing and coach/self-training split
5. Theme and visual polish including Kamen Rider assets
6. Cleanup and module removal
