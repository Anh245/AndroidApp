import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// Native HTTP clients do not have a browser cookie jar. Persist only this API's
// refresh cookie, and send it only to its /auth endpoints.
class RefreshCookieClient extends http.BaseClient {
  final http.Client inner;
  final Uri baseUri;
  final FlutterSecureStorage storage;
  RefreshCookieClient(this.inner, this.baseUri,
      {this.storage = const FlutterSecureStorage()});

  String get _key => 'refresh_cookie_${base64Url.encode(utf8.encode(baseUri.toString()))}';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authPath = '${baseUri.path}/auth';
    final isAuth = request.url.origin == baseUri.origin &&
        (request.url.path == authPath || request.url.path.startsWith('$authPath/'));
    if (isAuth) {
      request.followRedirects = false;
      final saved = await storage.read(key: _key);
      if (saved != null) {
        final cookie = jsonDecode(saved) as Map<String, dynamic>;
        final expiresAt = DateTime.parse(cookie['expiresAt'] as String);
        if (expiresAt.isAfter(DateTime.now())) {
          if (cookie['secure'] != true || request.url.scheme == 'https') {
            request.headers['Cookie'] = cookie['value'] as String;
          }
        } else {
          await storage.delete(key: _key);
        }
      }
    }
    final response = await inner.send(request);
    if (isAuth) {
      final header = response.headers['set-cookie'];
      if (header != null && header.startsWith('refreshToken=')) {
        final value = header.split(';').first;
        final maxAge = RegExp(r'max-age=(-?\d+)', caseSensitive: false).firstMatch(header);
        final seconds = int.tryParse(maxAge?.group(1) ?? '') ?? 0;
        if (value == 'refreshToken=' || seconds <= 0) {
          await storage.delete(key: _key);
        } else {
          await storage.write(key: _key, value: jsonEncode({
            'value': value,
            'expiresAt': DateTime.now().toUtc().add(Duration(seconds: seconds)).toIso8601String(),
            'secure': RegExp(r';\s*secure(?:;|$)', caseSensitive: false).hasMatch(header),
          }));
        }
      }
    }
    return response;
  }

  @override
  void close() => inner.close();
}
