import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_manager/core/api.dart';
import 'package:expense_manager/core/session.dart';
import 'package:expense_manager/core/theme.dart';
import 'package:expense_manager/screens/auth_screen.dart';
import 'package:expense_manager/screens/editors.dart';
import 'package:expense_manager/screens/home_screen.dart';

double contrast(Color a, Color b) =>
    (math.max(a.computeLuminance(), b.computeLuminance()) + 0.05) /
    (math.min(a.computeLuminance(), b.computeLuminance()) + 0.05);

void main() {
  test('semantic text and focus colors meet contrast thresholds', () {
    final theme = expenseTheme();
    final c = theme.colorScheme;
    for (final pair in [
      [c.onSurface, c.surface],
      [c.onSurfaceVariant, c.surface],
      [c.onSurfaceVariant, c.surfaceContainerLowest],
      [c.onPrimary, c.primary],
      [c.secondary, c.surfaceContainerLowest],
      [c.tertiary, c.surfaceContainerLowest],
      [c.error, c.surface],
      [c.onError, c.error],
      [c.onSurface, c.secondaryContainer],
      [c.secondary, c.secondaryContainer],
    ]) {
      expect(contrast(pair[0], pair[1]), greaterThanOrEqualTo(4.5));
    }
    final border = theme.inputDecorationTheme.focusedBorder!.borderSide;
    expect(
      contrast(border.color, c.surfaceContainerLowest),
      greaterThanOrEqualTo(3),
    );
    expect(contrast(border.color, c.primary), greaterThanOrEqualTo(3));
    expect(border.width, greaterThanOrEqualTo(2));
    expect(
      contrast(c.outline, c.surfaceContainerLowest),
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets('Tab reaches fields and buttons with themed focus indicators', (
    tester,
  ) async {
    final field = FocusNode();
    final button = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        theme: expenseTheme(),
        home: Scaffold(
          body: Column(
            children: [
              TextField(
                focusNode: field,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              FilledButton(
                focusNode: button,
                onPressed: () {},
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(field.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(button.hasFocus, isTrue);
    final style = Theme.of(
      tester.element(find.byType(FilledButton)),
    ).filledButtonTheme.style!;
    expect(style.side!.resolve({WidgetState.focused})!.width, 3);
    await tester.pumpWidget(const SizedBox());
    field.dispose();
    button.dispose();
  });

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('screens fit $size at text scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final category = {
          'id': 'food',
          'name': 'Ăn uống',
          'kind': 'expense',
          'color': '#F97316',
        };
        final api = Api(
          client: MockClient((req) async {
            final path = req.url.path;
            dynamic data;
            if (path.endsWith('/categories')) {
              data = [category];
            } else if (path.endsWith('/budgets')) {
              data = [
                {
                  'id': 'b',
                  'categoryId': 'food',
                  'categoryName': 'Ăn uống',
                  'color': '#F97316',
                  'amount': '500000',
                  'spent': '650000',
                },
              ];
            } else if (path.endsWith('/transactions')) {
              data = {
                'items': [
                  {
                    'id': 't',
                    'categoryId': 'food',
                    'categoryName': 'Ăn uống',
                    'color': '#F97316',
                    'kind': 'expense',
                    'amount': '650000',
                    'note': 'Bữa trưa',
                    'occurredOn': '2026-11-08',
                  },
                ],
                'total': 1,
              };
            } else {
              data = {
                'income': '1000000',
                'expense': '650000',
                'balance': '350000',
                'count': 1,
                'byCategory': [
                  {'name': 'Ăn uống', 'color': '#F97316', 'amount': '650000'},
                ],
                'trend': [
                  {
                    'month': '2026-11',
                    'income': '1000000',
                    'expense': '650000',
                  },
                ],
              };
            }
            return http.Response.bytes(utf8.encode(jsonEncode(data)), 200);
          }),
        );
        final session = Session(api)
          ..user = {'id': 'test', 'name': 'Test', 'email': 'test@example.com'};
        Future<void> show(Widget screen) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: expenseTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: screen,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await show(AuthScreen(session: session));
        await tester.ensureVisible(find.text('Chưa có tài khoản? Đăng ký'));
        await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await show(HomeScreen(session: session));
        if (size == const Size(375, 812) && scale == 1.0) {
          await tester.ensureVisible(find.text('Bữa trưa'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Bữa trưa'));
          await tester.pumpAndSettle();
          expect(find.byType(TransactionEditor), findsOneWidget);
          Navigator.of(tester.element(find.byType(TransactionEditor))).pop();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Xem tất cả'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Xem tất cả'));
          await tester.pumpAndSettle();
          expect(find.text('1 giao dịch phù hợp'), findsOneWidget);
          await tester.tap(find.text('Tổng quan').last);
          await tester.pumpAndSettle();
        }
        // Exercise every lazily built summary section, including trend rows.
        await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final tab in ['Giao dịch', 'Ngân sách', 'Danh mục']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await show(TransactionEditor(api: api, categories: [category]));
        await show(CategoryEditor(api: api));
        await show(
          BudgetEditor(api: api, categories: [category], month: '2026-11'),
        );
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        api.close();
      });
    }
  }
}
