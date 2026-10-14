import 'dart:async';
import 'dart:convert';
import 'api_client_native.dart'
    if (dart.library.js_interop) 'api_client_web.dart' as platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb
        ? 'http://localhost:3000/api'
        : 'http://10.0.2.2:3000/api',
  );
  final http.Client client;
  String? token;
  VoidCallback? onUnauthorized;
  Future<void> Function()? onRefresh;
  Future<void>? _refreshing;

  Future<void> waitForRefresh() async {
    final pending = _refreshing;
    if (pending != null) await pending;
  }

  Future<void> refreshSession() async {
    if (_refreshing != null) return _refreshing!;
    final refresh = onRefresh;
    if (refresh == null) throw ApiException('Vui lòng đăng nhập lại.', 401);
    final pending = refresh();
    _refreshing = pending;
    try {
      await pending;
    } finally {
      if (identical(_refreshing, pending)) _refreshing = null;
    }
  }
  Api({http.Client? client}) : client = client ?? platform.createApiClient(Uri.parse(baseUrl));
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) => _request(method, path, body: body, query: query);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool allowRefresh = true,
  }) async {
    final sentToken = token;
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    try {
      final request = http.Request(method, uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'application/json'
        ..headers['X-Requested-With'] = 'expense-manager';
      if (sentToken != null) {
        request.headers['Authorization'] = 'Bearer $sentToken';
      }
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      dynamic data;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          throw ApiException(
            'Máy chủ trả về dữ liệu không hợp lệ.',
            response.statusCode,
          );
        }
      }
      if (response.statusCode == 401 &&
          sentToken != null &&
          !path.startsWith('/auth/') &&
          allowRefresh &&
          onRefresh != null) {
        try {
          if (token == sentToken) await refreshSession();
        } on ApiException catch (error) {
          if (error.status == 401 && token == sentToken) onUnauthorized?.call();
          rethrow;
        }
        if (token == null) throw ApiException('Vui lòng đăng nhập lại.', 401);
        return _request(
          method, path, body: body, query: query, allowRefresh: false,
        );
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 &&
            sentToken != null &&
            token == sentToken) {
          onUnauthorized?.call();
        }
        final message = data is Map ? data['message']?.toString() : null;
        throw ApiException(
          message ?? 'Không thể thực hiện yêu cầu.',
          response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw ApiException('Kết nối quá lâu. Kiểm tra máy chủ và mạng.');
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được API. Kiểm tra địa chỉ máy chủ, Wi-Fi và cổng 3000.',
      );
    }
  }

  void close() => client.close();
}
