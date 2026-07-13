# Resource Hot Update Design

## Goal

Allow Pixel Planner to update approved non-executable visual resources after installation, while preserving APK upgrades for Flutter, native Android, database, and API-contract changes.

## Scope

The first delivery supports the two Kamen Rider ZZZ GIF assets. The architecture accepts additional approved theme image resources later. It does not evaluate or execute remotely delivered Dart, Java/Kotlin, JavaScript, or database migrations.

## Manifest Contract

`GET /api/v1/app/update-manifest` returns the existing application-version fields plus a `resources` array. Each resource has:

- `id`: stable logical identifier, initially `zzz.transform` or `zzz.shield`.
- `version`: monotonically increasing resource version string.
- `url`: absolute HTTPS download URL.
- `sha256`: lowercase SHA-256 checksum of the downloaded file.
- `contentType`: expected media type, initially `image/gif`.

The backend serves the resource files from a dedicated public assets directory at `/resources/<filename>`. It rejects path traversal and only serves declared files.

## Client Data Flow

1. On cold start and app resume, the existing update controller fetches the manifest.
2. A resource sync service filters the manifest through an app-owned allowlist.
3. For a changed resource, it downloads to a temporary file in the application support directory, hashes the bytes, then atomically replaces the cached file only after the checksum matches.
4. The service persists the active resource-version map in secure storage.
5. A resource resolver returns a local `FileImage` when a verified cached file exists; otherwise it returns the matching bundled `AssetImage`.
6. The ZZZ planner and settings visuals read through the resolver and rebuild after a successful sync.

## Failure and Security Rules

- Invalid URL scheme, unknown resource id, unsupported content type, oversized download, network failure, checksum mismatch, and filesystem errors leave the previous cached file untouched.
- A failed sync never blocks the application and never removes the bundled fallback.
- The first delivery limits an individual resource to 12 MiB and permits only HTTPS URLs in production. Tests may use a fake downloader rather than live HTTP.
- The manifest is advisory: it cannot introduce resource identifiers that the app has not shipped with.

## User Experience

When verified resources are activated, the update controller shows a short message: "主题资源已更新". The current update banner remains responsible for APK update notices. Resource-only updates do not ask the user to install an APK.

## Verification

Flutter unit tests cover allowlisting, checksum acceptance, checksum rejection with rollback, and bundled fallback resolution. Backend tests cover a manifest response and public resource serving. Widget tests verify the ZZZ visual uses a cached file when one is available.
