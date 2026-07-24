import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import '../domain/remote_resource.dart';

final resourceCacheProvider = Provider<ResourceCache>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ResourceCache(
    fetchBytes: (url) async {
      final response = await dio.get<List<int>>(
        resolveResourceUrlForDownload(dio.options.baseUrl, url),
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const <int>[];
    },
    rootDirectoryProvider: getApplicationSupportDirectory,
  );
});
String resolveResourceUrlForDownload(String baseUrl, String resourceUrl) {
  final parsedResource = Uri.tryParse(resourceUrl);
  if (parsedResource == null) {
    return resourceUrl;
  }
  if (parsedResource.hasScheme) {
    return resourceUrl;
  }

  final parsedBase = Uri.tryParse(baseUrl);
  if (parsedBase == null || !parsedBase.hasScheme) {
    return resourceUrl;
  }

  if (resourceUrl.startsWith('/')) {
    final origin = parsedBase.replace(path: '', query: '', fragment: '');
    return origin.resolve(resourceUrl).toString();
  }

  return parsedBase.resolve(resourceUrl).toString();
}

class ResourceSyncResult {
  const ResourceSyncResult({
    required this.changedCount,
    required this.failedCount,
  });

  final int changedCount;
  final int failedCount;
}

typedef ResourceByteFetcher = Future<List<int>> Function(String url);
typedef ResourceRootDirectoryProvider = Future<Directory> Function();

class ResourceCache {
  ResourceCache({
    required ResourceByteFetcher fetchBytes,
    required ResourceRootDirectoryProvider rootDirectoryProvider,
  })  : _fetchBytes = fetchBytes,
        _rootDirectoryProvider = rootDirectoryProvider;

  final ResourceByteFetcher _fetchBytes;
  final ResourceRootDirectoryProvider _rootDirectoryProvider;

  static const Map<String, String> fallbackAssets = {
    'zzz.transform': 'assets/themes/zzz/transform.gif',
    'zzz.shield': 'assets/themes/zzz/shield.gif',
    'zzz.equipment': 'assets/themes/zzz/equipment.gif',
    'zzz.flight': 'assets/themes/zzz/flight.gif',
    'zzz.rain': 'assets/themes/zzz/rain.gif',
  };

  Future<ResourceSyncResult> syncResources(
      List<RemoteResource> resources) async {
    var changedCount = 0;
    var failedCount = 0;
    final root = await _ensureRootDirectory();

    for (final resource in resources) {
      if (!resource.isValid || !fallbackAssets.containsKey(resource.id)) {
        continue;
      }

      try {
        final targetFile =
            File('${root.path}/${_resourceFileName(resource.id)}');
        if (await targetFile.exists()) {
          final existingHash = await _hashFile(targetFile);
          if (existingHash.toUpperCase() == resource.sha256.toUpperCase()) {
            continue;
          }
        }

        final bytes = await _fetchBytes(resource.url);
        if (bytes.isEmpty) {
          throw const FileSystemException('Empty resource payload');
        }

        final payloadHash = sha256.convert(bytes).toString().toUpperCase();
        if (payloadHash != resource.sha256.toUpperCase()) {
          throw const FileSystemException('Resource hash mismatch');
        }

        final tempFile = File('${targetFile.path}.tmp');
        await tempFile.writeAsBytes(bytes, flush: true);
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempFile.rename(targetFile.path);
        changedCount += 1;
      } catch (_) {
        failedCount += 1;
      }
    }

    return ResourceSyncResult(
      changedCount: changedCount,
      failedCount: failedCount,
    );
  }

  Future<File?> resolveFile(String resourceId) async {
    final root = await _ensureRootDirectory();
    final file = File('${root.path}/${_resourceFileName(resourceId)}');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<Directory> _ensureRootDirectory() async {
    final baseDirectory = await _rootDirectoryProvider();
    final root = Directory('${baseDirectory.path}/resource_cache');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  String _resourceFileName(String resourceId) {
    final normalized = resourceId.replaceAll('.', '_');
    return '$normalized.gif';
  }

  Future<String> _hashFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString().toUpperCase();
  }
}
