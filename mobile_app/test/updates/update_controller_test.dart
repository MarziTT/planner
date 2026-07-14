import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/updates/data/resource_cache.dart';
import 'package:pixel_planner_mobile/features/updates/data/update_repository.dart';
import 'package:pixel_planner_mobile/features/updates/domain/remote_resource.dart';
import 'package:pixel_planner_mobile/features/updates/state/update_controller.dart';

class _FakeUpdateRepository extends UpdateRepository {
  _FakeUpdateRepository(this.info) : super(Dio());

  final UpdateInfo info;

  @override
  Future<UpdateInfo?> checkVersion() async => info;
}

void main() {
  test('manual resource update retries sync and clears pending resources',
      () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('update-controller-test');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final bytes = utf8.encode('new-zzz-gif');
    final hash = sha256.convert(bytes).toString().toUpperCase();
    var failFirstRequest = true;
    final resourceCache = ResourceCache(
      fetchBytes: (_) async {
        if (failFirstRequest) {
          failFirstRequest = false;
          return utf8.encode('wrong-payload');
        }
        return bytes;
      },
      rootDirectoryProvider: () async => tempDirectory,
    );
    final info = UpdateInfo(
      version: '5.0.0',
      required: false,
      releaseNotes: const [],
      downloadUrl: '',
      buildNumber: '50000',
      resources: [
        RemoteResource(
          id: 'zzz.transform',
          version: '2026.07.14.1',
          url: '/api/v1/app/resources/zzz-transform.gif',
          sha256: hash,
          contentType: 'image/gif',
        ),
      ],
    );
    final controller = UpdateController(
      _FakeUpdateRepository(info),
      resourceCache,
    );

    await controller.check();

    expect(controller.state.info?.resources, isNotEmpty);
    expect(controller.state.resourceRevision, 0);
    expect(controller.state.lastActionMessage, contains('失败'));

    await controller.applyResourceUpdateNow();

    expect(controller.state.info?.resources, isEmpty);
    expect(controller.state.resourceRevision, 1);
    expect(controller.state.lastActionMessage, contains('已更新'));
    final file = await resourceCache.resolveFile('zzz.transform');
    expect(await file!.readAsBytes(), bytes);
  });
}
