import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'api_client.dart';

class FileCacheService {
  FileCacheService._();
  static final FileCacheService instance = FileCacheService._();

  final ApiClient _api = ApiClient.instance;

  Future<Directory> _getCacheDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/equipex_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Gets a file from cache or downloads it.
  /// Use for documents and media.
  Future<File> getFile(String urlPath) async {
    if (kIsWeb) {
      throw UnsupportedError('File caching is not supported on web.');
    }

    final cacheDir = await _getCacheDir();
    final hashedName = _hashUrl(urlPath);
    
    // We try to guess the extension from the URL if possible, otherwise leave it off.
    final ext = urlPath.contains('.') ? '.${urlPath.split('.').last.split('?').first}' : '';
    final localFile = File('${cacheDir.path}/$hashedName$ext');

    if (await localFile.exists()) {
      return localFile;
    }

    // Download it
    final response = await _api.getFile(urlPath);
    await localFile.writeAsBytes(response.bodyBytes);
    return localFile;
  }

  /// Gets an image from cache or downloads it.
  /// If it's a full URL (like GCS), it downloads directly.
  Future<File> getImage(String path) async {
    if (kIsWeb) {
      throw UnsupportedError('File caching is not supported on web.');
    }

    final cacheDir = await _getCacheDir();
    final url = ApiClient.resolveUrl(path) ?? path;
    final hashedName = _hashUrl(url);
    
    final ext = url.contains('.') ? '.${url.split('.').last.split('?').first}' : '';
    final localFile = File('${cacheDir.path}/$hashedName$ext');

    if (await localFile.exists()) {
      return localFile;
    }

    // Download the image bytes
    if (path.startsWith('http')) {
       // It's a direct GCS URL, don't use ApiClient (which adds auth headers)
       final request = await HttpClient().getUrl(Uri.parse(url));
       final response = await request.close();
       final bytes = await consolidateHttpClientResponseBytes(response);
       await localFile.writeAsBytes(bytes);
    } else {
       // It's a backend endpoint
       final response = await _api.getFile(path);
       await localFile.writeAsBytes(response.bodyBytes);
    }

    return localFile;
  }

  /// Wipes the entire cache directory. Call this on logout.
  Future<void> clearCache() async {
    if (kIsWeb) return;
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
