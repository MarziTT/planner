class RemoteResource {
  const RemoteResource({
    required this.id,
    required this.version,
    required this.url,
    required this.sha256,
    required this.contentType,
  });

  final String id;
  final String version;
  final String url;
  final String sha256;
  final String contentType;

  factory RemoteResource.fromJson(Map<String, dynamic> json) {
    return RemoteResource(
      id: json['id'] as String? ?? '',
      version: json['version'] as String? ?? '',
      url: json['url'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
    );
  }

  bool get isValid =>
      id.isNotEmpty &&
      version.isNotEmpty &&
      url.isNotEmpty &&
      sha256.isNotEmpty;
}
