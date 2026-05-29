import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'catalog_track_manifest.dart';

class CatalogClient {
  CatalogClient({
    String? baseUrl,
    HttpClient? httpClient,
  })  : baseUrl = _normalizeBaseUrl(baseUrl ?? defaultBaseUrl),
        _httpClient = httpClient ?? HttpClient();

  static const String defaultBaseUrl = String.fromEnvironment(
    'WAVEZERO_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final String baseUrl;
  final HttpClient _httpClient;

  Future<CatalogIndex> fetchCatalog() async {
    final json = await _getJsonObject('$baseUrl/catalog');
    return CatalogIndex.fromJson(json);
  }

  Future<CatalogTrackManifest> fetchTrackManifest({
    String trackId = 'track-apple-bipbop-hls',
  }) async {
    final json = await _getJsonObject('$baseUrl/tracks/$trackId/manifest');
    return CatalogTrackManifest.fromJson(json);
  }

  Future<Map<String, Object?>> _getJsonObject(String url) async {
    final uri = Uri.parse(url);
    final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogClientException(
        'Catalog API returned HTTP ${response.statusCode} for $uri',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Catalog API response is not a JSON object');
    }
    return decoded;
  }

  void close() => _httpClient.close(force: true);

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) return trimmed.substring(0, trimmed.length - 1);
    return trimmed;
  }
}

class CatalogClientException implements Exception {
  const CatalogClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
