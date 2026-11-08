import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_manager/core/api.dart';
import 'package:expense_manager/core/session.dart';
import 'package:expense_manager/core/theme.dart';
import 'package:expense_manager/screens/home_screen.dart';

void main() {
  for (final longAmounts in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Midnight sections and dock with long amounts=$longAmounts, scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final categories = [
            {
              'id': 'food',
              'name': 'Ăn uống',
              'kind': 'expense',
              'color': '#BEF264',
              'amount': '3375000',
            },
            {
              'id': 'shopping',
              'name': 'Mua sắm',
              'kind': 'expense',
              'color': '#91DFC2',
              'amount': '2025000',
            },
            {
              'id': 'travel',
              'name': 'Di chuyển',
              'kind': 'expense',
              'color': '#E3F5B5',
              'amount': '1350000',
            },
          ];
          final transactions = [
            {
              'id': 't1',
              'categoryId': 'food',
              'categoryName': 'Ăn uống',
              'kind': 'expense',
              'color': '#BEF264',
              'amount': longAmounts ? '1200000000' : '65000',
              'note': 'Ăn trưa',
              'occurredOn': '2026-11-08',
            },
            {
              'id': 't2',
              'categoryId': 'food',
              'categoryName': 'Ăn uống',
              'kind': 'expense',
              'color': '#BEF264',
              'amount': '35000',
              'note': 'Cà phê',
              'occurredOn': '2026-11-08',
            },
          ];
          final api = Api(
            client: MockClient((req) async {
              dynamic data;
              if (req.url.path.endsWith('/categories')) {
                data = categories;
              } else if (req.url.path.endsWith('/budgets')) {
                data = [];
              } else if (req.url.path.endsWith('/transactions')) {
                data = {'items': transactions, 'total': 2};
              } else {
                data = {
                  'income': longAmounts ? '30000700000' : '15000000',
                  'expense': longAmounts ? '1320000065' : '6750000',
                  'balance': longAmounts ? '28680699935' : '8250000',
                  'count': 2,
                  'byCategory': longAmounts
                      ? [
                          {...categories[0], 'amount': '1200000000'},
                          {...categories[1], 'amount': '120000000'},
                          {...categories[2], 'amount': '65'},
                        ]
                      : categories,
                  'trend': [
                    {
                      'month': '2026-11',
                      'income': '15000000',
                      'expense': '6750000',
                    },
                  ],
                };
              }
              return http.Response.bytes(utf8.encode(jsonEncode(data)), 200);
            }),
          );
          final session = Session(api)
            ..user = {
              'id': 'preview',
              'name': 'Test',
              'email': 'test@example.com',
            };
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
          expect(tester.takeException(), isNull);
          expect(find.byType(FloatingActionButton), findsNothing);
          final action = tester.getRect(
            find.byKey(const ValueKey('primary-add-action')),
          );
          final nav = tester.getRect(find.byType(NavigationBar));
          expect(action.width, 328);
          expect(action.bottom, lessThanOrEqualTo(nav.top));
          if (scale == 1) {
            final ring = tester.getRect(
              find.byKey(const ValueKey('category-ring')),
            );
            final legend = tester.getRect(
              find.byKey(const ValueKey('category-legend')),
            );
            expect(ring.right, lessThan(legend.left));
            expect((ring.center.dy - legend.center.dy).abs(), lessThan(1));
            expect(
              tester.getTopLeft(find.text('Giao dịch gần đây')).dy,
              lessThan(action.top),
            );
            final income = tester.getTopLeft(find.text('Thu nhập'));
            final expense = tester.getTopLeft(find.text('Chi tiêu').first);
            expect(income.dy, expense.dy);
          }
          await tester.ensureVisible(find.text('Thu – chi 6 tháng'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Thu – chi 6 tháng'));
          await tester.pumpAndSettle();
          expect(find.text('11/2026'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Thêm giao dịch'));
          await tester.pumpAndSettle();
          expect(find.text('Số tiền'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          session.dispose();
          api.close();
        },
      );
    }
  }
}
