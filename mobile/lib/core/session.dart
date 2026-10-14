import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';

class Session extends ChangeNotifier {
  final Api api;
  final FlutterSecureStorage storage;
  Map<String, dynamic>? user;
  String? startupError;
  bool loading = true;
  bool _loggingOut = false;
  int _generation = 0;

  Session(this.api, {this.storage = const FlutterSecureStorage()}) {
    api.onUnauthorized = () { expire(); };
    api.onRefresh = _refresh;
  }

  Future<void> _refresh() async {
    if (_loggingOut) throw ApiException('Đang đăng xuất.');
    final generation = _generation;
    final data = await api.request('POST', '/auth/refresh');
    if (generation != _generation) throw ApiException('Phiên đã thay đổi.', 401);
    api.token = data['accessToken'] as String;
  }

  Future<void> restore() async {
    loading = true;
    startupError = null;
    notifyListeners();
    try {
      // Access token stays in memory; the HTTP client sends the saved cookie.
      await storage.delete(key: 'session_tokens');
      await storage.delete(key: 'session_token');
      await api.refreshSession();
      user = Map<String, dynamic>.from(await api.request('GET', '/users/me'));
    } on ApiException catch (e) {
      if (e.status == 401) {
        await expire();
      } else {
        startupError = e.message;
      }
    } catch (_) {
      startupError = 'Không đọc được phiên đăng nhập trên thiết bị.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password, {String? name}) async {
    final credentials = <String, dynamic>{'email': email.trim(), 'password': password};
    if (name != null) {
      await api.request('POST', '/auth/register',
        body: {...credentials, 'name': name.trim()});
    }
    final data = await api.request('POST', '/auth/login', body: credentials);
    _generation++;
    api.token = data['accessToken'] as String;
    user = Map<String, dynamic>.from(data['user']);
    startupError = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _loggingOut = true;
    try {
      try {
        await api.waitForRefresh();
      } on ApiException catch (e) {
        if (e.status != 401) rethrow;
      }
      await api.request('POST', '/auth/logout');
      await expire();
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> expire() async {
    _generation++;
    api.token = null;
    user = null;
    notifyListeners();
  }
}
