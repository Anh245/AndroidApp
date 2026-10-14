import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_manager/core/api.dart';
import 'package:expense_manager/core/refresh_cookie_client.dart';
import 'package:expense_manager/core/format.dart';
import 'package:expense_manager/core/session.dart';
import 'package:expense_manager/screens/auth_screen.dart';
import 'package:expense_manager/screens/home_screen.dart';

void main() {
  test('VND validation rejects zero, fractions, empty and over limit', () {
    for (final value in ['', '0', '-10', '1.5', '1000000000001']) {
      expect(validateAmount(value), isNotNull);
    }
    expect(validateAmount('50000'), isNull);
    expect(money('50000'), '50.000 ₫');
    expect(monthKey(DateTime(2026, 1)), '2026-01');
    expect(displayDate('2026-10-12'), '12/10/2026');
  });
  test('API sends bearer token and preserves Vietnamese JSON', () async {
    final api = Api(
      client: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer test-token');
        expect(jsonDecode(req.body)['note'], 'Ăn trưa');
        return http.Response.bytes(utf8.encode('{"message":"Đã lưu"}'), 201);
      }),
    )..token = 'test-token';
    expect(
      (await api.request(
        'POST',
        '/transactions',
        body: {'note': 'Ăn trưa'},
      ))['message'],
      'Đã lưu',
    );
    api.close();
  });
  test(
    '401 expires authenticated session and exposes actionable message',
    () async {
      var expired = false;
      final api = Api(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode('{"message":"Phiên hết hạn"}'),
            401,
          ),
        ),
      )..token = 'test-token';
      api.onUnauthorized = () => expired = true;
      await expectLater(
        api.request('GET', '/auth/me'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(expired, isTrue);
      api.close();
    },
  );
  test('concurrent 401 responses share one refresh and retry with the new token', () async {
    final gate = Completer<void>();
    var refreshes = 0;
    var calls = 0;
    final api = Api(client: MockClient((req) async {
      calls++;
      if (req.headers['Authorization'] == 'Bearer old') {
        return http.Response('{"message":"Expired"}', 401);
      }
      expect(req.headers['Authorization'], 'Bearer new');
      return http.Response('{"ok":true}', 200);
    }))..token = 'old';
    api.onRefresh = () async {
      refreshes++;
      await gate.future;
      api.token = 'new';
    };
    final first = api.request('GET', '/users/me');
    final second = api.request('GET', '/categories');
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, 4);
    api.close();
  });
  test('transient refresh failure keeps the session; refresh 401 expires it', () async {
    for (final status in [503, 429, 0, 401]) {
      var expired = false;
      final api = Api(client: MockClient((_) async => http.Response('{}', 401)))..token = 'old';
      api.onUnauthorized = () => expired = true;
      api.onRefresh = () async { throw ApiException('Refresh failed', status); };
      await expectLater(api.request('GET', '/users/me'), throwsA(isA<ApiException>()));
      expect(expired, status == 401);
      api.close();
    }
  });
  test('retried request cannot enter an endless refresh loop', () async {
    var refreshes = 0;
    var expired = false;
    final api = Api(client: MockClient((_) async => http.Response('{}', 401)))..token = 'old';
    api.onUnauthorized = () => expired = true;
    api.onRefresh = () async { refreshes++; api.token = 'new'; };
    await expectLater(api.request('GET', '/users/me'), throwsA(isA<ApiException>()));
    expect(refreshes, 1);
    expect(expired, isTrue);
    api.close();
  });
  test('native client restores and clears refresh cookie without JSON tokens', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final paths = <String>[];
    http.Client transport() => MockClient((req) async {
      paths.add(req.url.path);
      expect(req.headers['X-Requested-With'], 'expense-manager');
      if (req.url.path.endsWith('/auth/register')) {
        return http.Response('{"message":"Created"}', 201);
      }
      if (req.url.path.endsWith('/auth/login')) {
        return http.Response(jsonEncode({
          'accessToken': 'access',
          'user': {'id': 'user', 'name': 'Test', 'email': 'test@example.com'},
        }), 200, headers: {
          'set-cookie': 'refreshToken=saved-cookie; Max-Age=1209600; Path=/api/auth; HttpOnly; SameSite=Lax',
        });
      }
      if (req.url.path.endsWith('/auth/refresh')) {
        expect(req.body, isEmpty);
        if (req.headers['Cookie'] != 'refreshToken=saved-cookie') {
          return http.Response('{}', 401);
        }
        return http.Response('{"accessToken":"renewed-access"}', 200);
      }
      if (req.url.path.endsWith('/auth/logout')) {
        expect(req.body, isEmpty);
        expect(req.headers['Cookie'], 'refreshToken=saved-cookie');
        return http.Response('', 204, headers: {
          'set-cookie': 'refreshToken=; Path=/api/auth; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly; SameSite=Lax',
        });
      }
      expect(req.headers['Cookie'], isNull);
      expect(req.headers['Authorization'], 'Bearer renewed-access');
      return http.Response('{"id":"user","name":"Test","email":"test@example.com"}', 200);
    });
    Api makeApi() => Api(client: RefreshCookieClient(transport(), Uri.parse(Api.baseUrl)));
    final firstApi = makeApi();
    final firstSession = Session(firstApi);
    await firstSession.signIn('test@example.com', 'Password123!', name: 'Test');
    expect(paths.take(2), ['/api/auth/register', '/api/auth/login']);
    expect(await firstSession.storage.read(key: 'session_tokens'), isNull);
    firstSession.dispose();
    firstApi.close();
    final restoredApi = makeApi();
    final restored = Session(restoredApi);
    await restored.restore();
    expect(restored.user?['id'], 'user');
    expect(restoredApi.token, 'renewed-access');
    await restored.logout();
    await restored.restore();
    expect(restored.user, isNull);
    expect(restoredApi.token, isNull);
    restored.dispose();
    restoredApi.close();
  });
  test('native refresh cookie is scoped to API origin and auth path', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final baseUri = Uri.parse('https://api.example.com/api');
    final client = RefreshCookieClient(MockClient((req) async {
      if (req.url.path.endsWith('/login')) {
        return http.Response('{}', 200, headers: {
          'set-cookie': 'refreshToken=secret; Max-Age=1209600; Path=/api/auth; HttpOnly; Secure; SameSite=None',
        });
      }
      if (req.url.origin == baseUri.origin && req.url.path == '/api/auth/refresh') {
        expect(req.headers['Cookie'], 'refreshToken=secret');
      } else {
        expect(req.headers['Cookie'], isNull);
      }
      return http.Response('{}', 200);
    }), baseUri);
    await client.post(Uri.parse('https://api.example.com/api/auth/login'));
    await client.post(Uri.parse('https://api.example.com/api/auth/refresh'));
    await client.get(Uri.parse('https://api.example.com/api/users/me'));
    await client.post(Uri.parse('https://other.example.com/api/auth/refresh'));
    await client.post(Uri.parse('http://api.example.com/api/auth/refresh'));
    client.close();
  });
  testWidgets('login form validates before making a request', (tester) async {
    var calls = 0;
    final api = Api(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    final session = Session(api);
    await tester.pumpWidget(MaterialApp(home: AuthScreen(session: session)));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
    expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.close();
  });
  testWidgets(
    'dashboard loads API summary and navigates to empty transactions',
    (tester) async {
      final api = Api(
        client: MockClient((req) async {
          dynamic result;
          if (req.url.path.endsWith('/categories') ||
              req.url.path.endsWith('/budgets')) {
            result = [];
          } else if (req.url.path.endsWith('/transactions')) {
            result = {'items': [], 'total': 0};
          } else {
            result = {
              'income': '1000000',
              'expense': '65000',
              'balance': '935000',
              'count': 2,
              'byCategory': [],
              'trend': [],
            };
          }
          return http.Response(jsonEncode(result), 200);
        }),
      );
      final session = Session(api)
        ..user = {'id': 'test', 'name': 'Hiệp', 'email': 'hiep@example.com'};
      await tester.pumpWidget(MaterialApp(home: HomeScreen(session: session)));
      await tester.pumpAndSettle();
      expect(find.text('935.000 ₫'), findsOneWidget);
      expect(find.text('1.000.000 ₫'), findsOneWidget);
      await tester.tap(find.text('Giao dịch').last);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có giao dịch phù hợp'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.close();
    },
  );
}
