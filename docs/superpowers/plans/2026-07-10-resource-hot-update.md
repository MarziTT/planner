# Resource Hot Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Download and activate verified ZZZ theme GIF resources without requiring an APK reinstall.

**Architecture:** The Flask API publishes a strict manifest and serves only declared resource files. Flutter filters that manifest by a fixed allowlist, downloads resources to application-support storage, verifies SHA-256, persists active local paths, and resolves cached images before bundled assets.

**Tech Stack:** Flask, pytest, Flutter, Riverpod, Dio, `path_provider`, `crypto`, `flutter_secure_storage`.

## Global Constraints

- Only `zzz.transform` and `zzz.shield` are eligible in the first release.
- Every remote file must be HTTPS in production and at most 12 MiB.
- A failed download or checksum never replaces a working cached file.
- Flutter/native logic changes still require an APK update.

---

### Task 1: Backend manifest and public resource endpoint

**Files:**
- Modify: `backend/app/config.py`
- Modify: `backend/app/api/updates.py`
- Modify: `assets/update_manifest.json`
- Create: `assets/resources/zzz-transform.gif`
- Create: `assets/resources/zzz-shield.gif`
- Test: `backend/tests/test_updates.py`

- [ ] Write a test asserting `/api/v1/app/update-manifest` returns both resource identifiers with a SHA-256 and an absolute URL.
- [ ] Run `pytest backend/tests/test_updates.py -q` and verify the missing endpoint behavior fails.
- [ ] Add an allowlisted resource endpoint and complete manifest entries.
- [ ] Run `pytest backend/tests/test_updates.py -q` and verify it passes.

### Task 2: Verified resource-cache service

**Files:**
- Modify: `mobile_app/pubspec.yaml`
- Create: `mobile_app/lib/features/updates/domain/resource_manifest.dart`
- Create: `mobile_app/lib/features/updates/data/resource_cache.dart`
- Test: `mobile_app/test/updates/resource_cache_test.dart`

- [ ] Write failing tests for unknown-id rejection, accepted SHA-256 download, and checksum mismatch rollback.
- [ ] Run `flutter test test/updates/resource_cache_test.dart` and verify failure due to absent cache service.
- [ ] Implement the minimal allowlisted cache service with temporary-file replacement.
- [ ] Run `flutter test test/updates/resource_cache_test.dart` and verify it passes.

### Task 3: Manifest parsing and controller integration

**Files:**
- Modify: `mobile_app/lib/features/updates/data/update_repository.dart`
- Modify: `mobile_app/lib/features/updates/state/update_controller.dart`
- Test: `mobile_app/test/updates/update_controller_test.dart`

- [ ] Write a failing test showing a valid resource-only response invokes the cache and exposes the activated-resource revision.
- [ ] Run `flutter test test/updates/update_controller_test.dart` and verify failure.
- [ ] Add resource DTO parsing and controller sync after version check.
- [ ] Run the focused test and verify it passes.

### Task 4: Cached image resolver and ZZZ visual integration

**Files:**
- Create: `mobile_app/lib/features/updates/presentation/resource_image.dart`
- Modify: `mobile_app/lib/features/planner/presentation/planner_dashboard.dart`
- Modify: `mobile_app/lib/features/settings/presentation/settings_page.dart`
- Test: `mobile_app/test/updates/resource_image_test.dart`

- [ ] Write a failing widget test showing a cached ZZZ file renders through `Image.file` and no cache renders the bundled asset.
- [ ] Run `flutter test test/updates/resource_image_test.dart` and verify failure.
- [ ] Implement `ResourceImage` and replace the two direct ZZZ `Image.asset` usages.
- [ ] Run focused widget tests and verify they pass.

### Task 5: Full verification

**Files:**
- Modify: `docs/superpowers/specs/2026-07-10-resource-hot-update-design.md` only if verification exposes a required correction.

- [ ] Run `pytest backend/tests -q`.
- [ ] Run `flutter test` from `mobile_app`.
- [ ] Run `flutter analyze` from `mobile_app`.
- [ ] Run `flutter build apk --debug` from `mobile_app`.
