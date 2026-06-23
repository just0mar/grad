import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../main.dart';
import '../auth/LoginView.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _client = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _refreshing = false;
  final List<Completer<void>> _waiters = [];

  Future<String?> get accessToken =>
      _storage.read(key: AppConfig.accessTokenKey);

  Future<String?> getFreshAccessToken({
    Duration refreshWindow = const Duration(minutes: 1),
  }) async {
    final token = await accessToken;
    if (token == null || token.isEmpty) return token;
    if (_isJwtExpiringSoon(token, refreshWindow) && await _tryRefresh()) {
      return accessToken;
    }
    return token;
  }

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConfig.refreshTokenKey);

  Future<String?> getUser() => _storage.read(key: AppConfig.userKey);

  Future<void> saveUser(String json) =>
      _storage.write(key: AppConfig.userKey, value: json);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConfig.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConfig.refreshTokenKey, value: refreshToken);
  }

  Future<void> saveActiveTeam(String teamId) =>
      _storage.write(key: AppConfig.activeTeamKey, value: teamId);

  Future<String?> getActiveTeam() =>
      _storage.read(key: AppConfig.activeTeamKey);

  Future<void> saveActiveClub(String clubId) =>
      _storage.write(key: AppConfig.activeClubKey, value: clubId);

  Future<String?> getActiveClub() =>
      _storage.read(key: AppConfig.activeClubKey);

  Future<void> clearSession() async {
    await _storage.delete(key: AppConfig.accessTokenKey);
    await _storage.delete(key: AppConfig.refreshTokenKey);
    await _storage.delete(key: AppConfig.userKey);
    await _storage.delete(key: AppConfig.activeTeamKey);
    await _storage.delete(key: AppConfig.activeClubKey);

    final context = MyApp.navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginView()),
        (route) => false,
      );
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = _uri(path, queryParams);
    var response = await _client.get(uri, headers: await _headers());
    if (response.statusCode == 401 && await _tryRefresh()) {
      response = await _client.get(uri, headers: await _headers());
    }
    return _handle(response);
  }

  /// POST using an explicitly supplied bearer token instead of the stored one.
  /// Used for endpoints that require a temporary JWT (e.g. complete-google-profile).
  Future<dynamic> postWithBearer(
    String path,
    String token, {
    Object? body,
  }) async {
    final uri = _uri(path);
    final encoded = body == null ? null : jsonEncode(body);
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: encoded,
    );
    return _handle(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final uri = _uri(path);
    final encoded = body == null ? null : jsonEncode(body);
    var response = await _client.post(
      uri,
      headers: await _headers(),
      body: encoded,
    );
    if (response.statusCode == 401 && await _tryRefresh()) {
      response = await _client.post(
        uri,
        headers: await _headers(),
        body: encoded,
      );
    }
    return _handle(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final uri = _uri(path);
    final encoded = body == null ? null : jsonEncode(body);
    var response = await _client.put(
      uri,
      headers: await _headers(),
      body: encoded,
    );
    if (response.statusCode == 401 && await _tryRefresh()) {
      response = await _client.put(
        uri,
        headers: await _headers(),
        body: encoded,
      );
    }
    return _handle(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final uri = _uri(path);
    final encoded = body == null ? null : jsonEncode(body);
    var response = await _client.patch(
      uri,
      headers: await _headers(),
      body: encoded,
    );
    if (response.statusCode == 401 && await _tryRefresh()) {
      response = await _client.patch(
        uri,
        headers: await _headers(),
        body: encoded,
      );
    }
    return _handle(response);
  }

  Future<dynamic> delete(String path) async {
    final uri = _uri(path);
    var response = await _client.delete(uri, headers: await _headers());
    if (response.statusCode == 401 && await _tryRefresh()) {
      response = await _client.delete(uri, headers: await _headers());
    }
    return _handle(response);
  }

  Future<dynamic> uploadFile(
    String path, {
    required String fileField,
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    final token = await accessToken;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (fields != null) request.fields.addAll(fields);
    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath, filename: fileName));
    }
    var streamed = await _client.send(request);
    var response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && await _tryRefresh()) {
      final retry = http.MultipartRequest('POST', _uri(path));
      final token = await accessToken;
      if (token != null) retry.headers['Authorization'] = 'Bearer $token';
      if (fields != null) retry.fields.addAll(fields);
      if (fileBytes != null) {
        retry.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName));
      } else if (filePath != null) {
        retry.files.add(await http.MultipartFile.fromPath(fileField, filePath, filename: fileName));
      }
      streamed = await _client.send(retry);
      response = await http.Response.fromStream(streamed);
    }
    return _handle(response);
  }

  Future<dynamic> uploadPutFile(
    String path, {
    required String fileField,
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('PUT', _uri(path));
    final token = await accessToken;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (fields != null) request.fields.addAll(fields);
    
    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath, filename: fileName));
    }

    var streamed = await _client.send(request);
    var response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && await _tryRefresh()) {
      final retry = http.MultipartRequest('PUT', _uri(path));
      final token = await accessToken;
      if (token != null) retry.headers['Authorization'] = 'Bearer $token';
      if (fields != null) retry.fields.addAll(fields);
      
      if (fileBytes != null) {
        retry.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName));
      } else if (filePath != null) {
        retry.files.add(await http.MultipartFile.fromPath(fileField, filePath, filename: fileName));
      }

      streamed = await _client.send(retry);
      response = await http.Response.fromStream(streamed);
    }
    return _handle(response);
  }

  /// GET a file endpoint and return the raw response (bytes + headers).
  /// Automatically intercepts 301/302 redirects and drops the Authorization header
  /// before following them (to prevent GCS 400 Bad Request errors).
  Future<http.Response> getFile(String path) async {
    final uri = _uri(path);
    final hdrs = await _headers();
    hdrs.remove('Content-Type');

    // Send request without auto-following redirects so we can strip auth if needed
    final request = http.Request('GET', uri)..headers.addAll(hdrs);
    request.followRedirects = false;
    
    var streamed = await _client.send(request);
    var response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && await _tryRefresh()) {
      final refreshedHdrs = await _headers();
      refreshedHdrs.remove('Content-Type');
      final retryReq = http.Request('GET', uri)..headers.addAll(refreshedHdrs);
      retryReq.followRedirects = false;
      streamed = await _client.send(retryReq);
      response = await http.Response.fromStream(streamed);
    }

    // Handle Redirects manually
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers['location'];
      if (location != null) {
        final redirectUri = Uri.parse(location);
        // Follow redirect WITHOUT our API authorization headers (GCS will reject them)
        final redirectResponse = await _client.get(redirectUri);
        if (redirectResponse.statusCode < 200 || redirectResponse.statusCode >= 300) {
          throw ApiException(redirectResponse.statusCode, 'Failed to download redirected file.');
        }
        // Preserve original content-disposition if the redirect target didn't provide one
        final newHeaders = Map<String, String>.from(redirectResponse.headers);
        if (!newHeaders.containsKey('content-disposition') && response.headers.containsKey('content-disposition')) {
          newHeaders['content-disposition'] = response.headers['content-disposition']!;
        }
        return http.Response(
          redirectResponse.body,
          redirectResponse.statusCode,
          headers: newHeaders,
          isRedirect: false,
          request: redirectResponse.request,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Failed to download file.');
    }
    return response;
  }

  static String? resolveUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${AppConfig.baseUrl}$path';
  }

  Future<Map<String, String>> _headers() async {
    final token = await accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    final base = Uri.parse(AppConfig.baseUrl);
    return base.replace(
      path: path.startsWith('/') ? path : '/$path',
      queryParameters: queryParams,
    );
  }

  dynamic _handle(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    var message = 'Request failed with status ${response.statusCode}';
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        message = (body['error'] ?? body['message'] ?? body['title'] ?? message)
            .toString();
      }
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  Future<bool> _tryRefresh() async {
    if (_refreshing) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
      return (await accessToken) != null;
    }

    _refreshing = true;
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final response = await _client.post(
        _uri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode != 200) {
        await clearSession();
        return false;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      await saveTokens(
        accessToken: json['accessToken'].toString(),
        refreshToken: (json['refreshToken'] ?? refreshToken).toString(),
      );
      for (final waiter in _waiters) {
        waiter.complete();
      }
      return true;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      await clearSession();
      return false;
    } finally {
      for (final waiter in _waiters.where((w) => !w.isCompleted)) {
        waiter.complete();
      }
      _waiters.clear();
      _refreshing = false;
    }
  }

  bool _isJwtExpiringSoon(String token, Duration refreshWindow) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) return false;
      final exp = json['exp'];
      final seconds = exp is int ? exp : int.tryParse(exp?.toString() ?? '');
      if (seconds == null) return false;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );
      return DateTime.now().toUtc().add(refreshWindow).isAfter(expiresAt);
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// A short, human-readable version of this error — safe to show directly
  /// in the UI. Never includes the "ApiException(...)" wrapper.
  String get userMessage => friendlyErrorText(this);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Converts any thrown [error] into a short, user-friendly message suitable for
/// display in a SnackBar or dialog.
///
/// This is the app's single place for turning technical errors (API failures,
/// dropped connections, timeouts) into language a user can understand. It never
/// exposes raw "ApiException(...)" or "Exception:" text. Pass an optional
/// [fallback] to customise the generic message for a given screen, e.g.
/// `friendlyErrorText(e, fallback: 'Could not update your profile.')`.
String friendlyErrorText(Object error, {String? fallback}) {
  final String defaultMsg =
      fallback ?? 'Something went wrong. Please try again.';

  if (error is ApiException) {
    switch (error.statusCode) {
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return "We couldn't find what you were looking for.";
      case 408:
        return 'The request timed out. Please try again.';
      case 429:
        return "You're doing that a bit too fast. Please wait a moment and try again.";
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Our servers are having a moment. Please try again shortly.';
    }
    final String msg = error.message.trim();
    // The server already returns readable validation messages (e.g.
    // "This username is already taken."). Surface those as-is, but fall back
    // to the friendly default for generic / empty / status-only messages.
    if (msg.isEmpty || msg.startsWith('Request failed with status')) {
      return defaultMsg;
    }
    return msg;
  }

  if (error is TimeoutException) {
    return 'The request timed out. Please try again.';
  }

  final String text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection closed')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (text.contains('TimeoutException')) {
    return 'The request timed out. Please try again.';
  }

  return defaultMsg;
}
