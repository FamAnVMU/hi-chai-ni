/// Configurable content source distribution settings.
/// Never hardcodes a single fixed download endpoint.
class ContentSourceConfig {
  final String baseUrl;
  final String apiVersion;
  final Map<String, String> defaultHeaders;

  static const String officialCdnBase =
      'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn';

  const ContentSourceConfig({
    this.baseUrl = officialCdnBase,
    this.apiVersion = 'v1',
    this.defaultHeaders = const {},
  });

  String getManifestUrl(String packId) {
    return '$baseUrl/manifests/${packId}_manifest.json';
  }

  String getPackageArchiveUrl(String packId) {
    return '$baseUrl/packages/$packId.zip';
  }

  String getAudioFileUrl(String packId, String relativePath) {
    final cleanRel = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    return '$baseUrl/audio/$packId/$cleanRel';
  }

  ContentSourceConfig copyWith({
    String? baseUrl,
    String? apiVersion,
    Map<String, String>? defaultHeaders,
  }) {
    return ContentSourceConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiVersion: apiVersion ?? this.apiVersion,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
    );
  }
}
