# PixelPlanner Ownership Plan

## Goal

Deliver a stable PixelPlanner project with complete HarmonyOS support, verified backend and Flutter behavior, reproducible D-drive packaging, device smoke tests, and committed source changes on G drive.

## Phases

- [x] Phase 1: Restore build, signing, install, and Flutter host page
- [ ] Phase 2: Reconcile handoff docs and current worktree
- [ ] Phase 3: Replace temporary OHOS storage and platform workarounds
- [ ] Phase 4: Complete required OHOS native bridges
- [ ] Phase 5: Fix app-level auth, routing, and persistence regressions
- [ ] Phase 6: Run backend and Flutter automated validation
- [ ] Phase 7: Run HarmonyOS device feature regression
- [ ] Phase 8: Package from fresh D-drive source and verify install
- [ ] Phase 9: Review, commit, push, and update handoff documentation

## Required HarmonyOS Coverage

- Startup and navigation
- Login, token persistence, session restore, and input retention
- Shared preferences and settings persistence
- Notifications and notification permissions
- Voice output, speech input, and recording
- File paths, import/export, sharing, URL launching, image selection
- Weather, network, updates, and agent workflows

## Product Direction

- The mobile app's primary internal experience is a chat-first command center.
- Existing dashboard, transit, meals, exercise, tags, profile, and settings remain available as on-demand modules.
- Keep backend APIs, packaging, signing, and native integration boundaries unchanged while evolving the UI.
- Remove the mobile health center and Huawei Health Kit integration. Do not add features that require Huawei developer-console scope approval.

## Rules

- Source edits and Git operations happen in G:\PixelPlanner.
- Packaging and device builds happen in D:\PixelPlannerBuild.
- Pull/sync latest source before every D-drive package.
- Never commit signing files, passwords, caches, or build outputs.
- Temporary in-memory fallbacks must not remain as final behavior.
