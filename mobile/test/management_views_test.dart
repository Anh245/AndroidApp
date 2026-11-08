import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_manager/core/api.dart';
import 'package:expense_manager/core/session.dart';
import 'package:expense_manager/core/theme.dart';
import 'package:expense_manager/screens/home_screen.dart';
import 'package:expense_manager/screens/editors.dart';

Session managementSession({bool longAmounts = false, List<Uri>? requests}) {
  final categories = [
    {
      'id': 'food',
      'name': longAmounts ? 'Ăn uống và các bữa ăn cùng gia đình' : 'Ăn uống',
      'kind': 'expense',
      'color': '#BEF264',
    },
    {
      'id': 'shopping',
      'name': 'Mua sắm',
      'kind': 'expense',
      'color': '#91DFC2',
    },
    {
      'id': 'travel',
      'name': 'Di chuyển',
      'kind': 'expense',
      'color': '#E3F5B5',
    },
    {'id': 'salary', 'name': 'Lương', 'kind': 'income', 'color': '#91DFC2'},
  ];
  final entries = [
    {
      'id': 't1',
      'categoryId': 'food',
      'categoryName': categories[0]['name'],
      'kind': 'expense',
      'color': '#BEF264',
      'amount': longAmounts ? '1200000000' : '65000',
      'note': 'Ăn trưa',
      'occurredOn': '2026-11-08',
      'paymentMethod': 'cash',
    },
    {
      'id': 't2',
      'categoryId': 'shopping',
      'categoryName': 'Mua sắm',
      'kind': 'expense',
      'color': '#91DFC2',
      'amount': '350000',
      'note': 'Mua đồ dùng',
      'occurredOn': '2026-11-08',
      'paymentMethod': 'other',
    },
    {
      'id': 't3',
      'categoryId': 'salary',
      'categoryName': 'Lương',
      'kind': 'income',
      'color': '#91DFC2',
      'amount': longAmounts ? '30000700000' : '15000000',
      'note': 'Lương tháng 11',
      'occurredOn': '2026-11-05',
      'paymentMethod': 'bank',
    },
  ];
  final api = Api(
    client: MockClient((req) async {
      requests?.add(req.url);
      dynamic data;
      if (req.url.path.endsWith('/categories')) {
        data = categories;
      } else if (req.url.path.endsWith('/budgets')) {
        data = [
          {
            'id': 'b1',
            'categoryId': 'food',
            'categoryName': categories[0]['name'],
            'color': '#BEF264',
            'amount': longAmounts ? '1000000000' : '4000000',
            'spent': longAmounts ? '1200000000' : '3400000',
          },
          {
            'id': 'b2',
            'categoryId': 'shopping',
            'categoryName': 'Mua sắm',
            'color': '#91DFC2',
            'amount': '2000000',
            'spent': '2500000',
          },
        ];
      } else if (req.url.path.endsWith('/transactions')) {
        final items = entries
            .where(
              (entry) =>
                  (!req.url.queryParameters.containsKey('kind') ||
                      entry['kind'] == req.url.queryParameters['kind']) &&
                  (!req.url.queryParameters.containsKey('search') ||
                      entry['note']!.contains(
                        req.url.queryParameters['search']!,
                      )),
            )
            .toList();
        data = {'items': items, 'total': items.length};
      } else {
        data = {
          'income': longAmounts ? '30000700000' : '15000000',
          'expense': '6750000',
          'balance': '8250000',
          'count': 3,
          'byCategory': [
            {'name': 'Ăn uống', 'color': '#BEF264', 'amount': '6750000'},
          ],
          'trend': [],
        };
      }
      return http.Response.bytes(utf8.encode(jsonEncode(data)), 200);
    }),
  );
  return Session(api)
    ..user = {'id': 'demo', 'name': 'Test', 'email': 'test@example.com'};
}

Future<void> mountManagement(
  WidgetTester tester,
  Session session, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: expenseTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: HomeScreen(session: session),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final longAmounts in [false, true]) {
      testWidgets('management actions at scale=$scale, long data=$longAmounts', (
        tester,
      ) async {
        final session = managementSession(longAmounts: longAmounts);
        await mountManagement(tester, session, scale: scale);
        for (final tab in ['Giao dịch', 'Ngân sách', 'Danh mục']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final tooltip =
              'Thao tác ${tab == 'Giao dịch'
                  ? 'giao dịch'
                  : tab == 'Ngân sách'
                  ? 'ngân sách'
                  : 'danh mục'}';
          // Scroll all content into layout, then reach an existing record's menu.
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -1800),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final menu = find.byTooltip(tooltip).first;
          await tester.ensureVisible(menu);
          await tester.pumpAndSettle();
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sửa'));
          await tester.pumpAndSettle();
          if (tab == 'Giao dịch')
            expect(find.byType(TransactionEditor), findsOneWidget);
          if (tab == 'Ngân sách')
            expect(find.byType(BudgetEditor), findsOneWidget);
          if (tab == 'Danh mục')
            expect(find.byType(CategoryEditor), findsOneWidget);
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
          await tester.pumpAndSettle();
          await tester.ensureVisible(menu);
          await tester.pumpAndSettle();
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Xóa'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.text('Hủy'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
        session.api.close();
        session.dispose();
      });
    }
  }

  testWidgets(
    'transaction filters, search and clear preserve monthly summary',
    (tester) async {
      final requests = <Uri>[];
      final session = managementSession(requests: requests);
      await mountManagement(tester, session);
      await tester.tap(find.text('Giao dịch').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Khoản thu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khoản thu'));
      await tester.pumpAndSettle();
      expect(
        requests.any((uri) => uri.queryParameters['kind'] == 'income'),
        isTrue,
      );
      expect(find.text('1 giao dịch phù hợp'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Lương');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (uri) =>
              uri.queryParameters['search'] == 'Lương' &&
              uri.queryParameters['kind'] == 'income',
        ),
        isTrue,
      );
      await tester.ensureVisible(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      final lastFiltered = requests.lastWhere(
        (uri) =>
            uri.path.endsWith('/transactions') &&
            uri.queryParameters['limit'] == '30',
      );
      expect(lastFiltered.queryParameters.containsKey('search'), isFalse);
      expect(find.text('Dòng tiền trong tháng'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.api.close();
      session.dispose();
    },
  );
}
