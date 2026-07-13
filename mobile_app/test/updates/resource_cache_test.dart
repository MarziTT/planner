import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/updates/data/resource_cache.dart';
import 'package:pixel_planner_mobile/features/updates/domain/remote_resource.dart';

void main() {
  test('syncResources saves verified resource bytes and resolves file',
      () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('resource-cache-test');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final bytes = utf8.encode('zzz-theme-gif');
    final hash = sha256.convert(bytes).toString().toUpperCase();
    final cache = ResourceCache(
      fetchBytes: (_) async => bytes,
      rootDirectoryProvider: () async => tempDirectory,
    );

    final result = await cache.syncResources([
      RemoteResource(
        id: 'zzz.transform',
        version: '2026.07.10.1',
        url: '/api/v1/app/resources/zzz-transform.gif',
        sha256: hash,
        contentType: 'image/gif',
      ),
    ]);

    final file = await cache.resolveFile('zzz.transform');
    expect(result.changedCount, 1);
    expect(result.failedCount, 0);
    expect(file, isNotNull);
    expect(await file!.readAsBytes(), bytes);
  });

  test('syncResources keeps resource missing when hash validation fails',
      () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('resource-cache-test');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final cache = ResourceCache(
      fetchBytes: (_) async => utf8.encode('broken-bytes'),
      rootDirectoryProvider: () async => tempDirectory,
    );

    final result = await cache.syncResources([
      const RemoteResource(
        id: 'zzz.shield',
        version: '2026.07.10.1',
        url: '/api/v1/app/resources/zzz-shield.gif',
        sha256: 'BADHASH',
        contentType: 'image/gif',
      ),
    ]);

    final file = await cache.resolveFile('zzz.shield');
    expect(result.changedCount, 0);
    expect(result.failedCount, 1);
    expect(file, isNull);
  });
}
