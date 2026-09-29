import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session.dart';

/// Base URL of the EasyPlay API. Override with
/// `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api` on a real device.
String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  // The Android emulator reaches the host machine via 10.0.2.2.
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000/api';
  return 'http://localhost:3000/api';
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Thin JSON client: adds the bearer token and refreshes it once on 401.
class ApiClient {
  ApiClient(this.session);
  final Session session;
  final _http = http.Client();

  Future<Map<String, dynamic>> get(String path, {Map<String, Object?>? query}) => _send('GET', path, query: query);
  Future<Map<String, dynamic>> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<Map<String, dynamic>> patch(String path, Object? body) => _send('PATCH', path, body: body);
  Future<Map<String, dynamic>> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);
  Future<Map<String, dynamic>> deleteWithBody(String path, Object body) => _send('DELETE', path, body: body);

  /// Multipart upload of a single file field.
  Future<Map<String, dynamic>> upload(String path, String field, String filePath, {bool retried = false}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl$path'))
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath(field, filePath));
    final token = session.accessToken;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode == 401 && !retried && session.refreshToken != null && await _refresh()) {
      return upload(path, field, filePath, retried: true);
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool retried = false,
  }) async {
    final params = <String, String>{
      for (final e in (query ?? const {}).entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: params.isEmpty ? null : params);

    final req = http.Request(method, uri)..headers['Accept'] = 'application/json';
    final token = session.accessToken;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final res = await http.Response.fromStream(await _http.send(req));

    if (res.statusCode == 401 && !retried && session.refreshToken != null) {
      if (await _refresh()) {
        return _send(method, path, query: query, body: body, retried: true);
      }
      await session.clear();
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    final json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, json['error']?.toString() ?? 'Request failed (${res.statusCode})');
    }
    return json;
  }

  Future<bool> _refresh() async {
    try {
      final res = await _http.post(
        Uri.parse('$apiBaseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': session.refreshToken}),
      );
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      await session.save(json['access_token'] as String, json['refresh_token'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }
}
