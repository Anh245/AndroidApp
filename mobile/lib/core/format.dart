import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

int amountOf(dynamic value) => int.tryParse(value.toString()) ?? 0;
String money(dynamic value) =>
    '${NumberFormat.decimalPattern('vi_VN').format(amountOf(value))} ₫';
String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String displayDate(String s) =>
    DateFormat('dd/MM/yyyy').format(DateTime.parse(s));
Color categoryColor(dynamic value) => Color(
  int.parse('FF${(value?.toString() ?? '#0F766E').substring(1)}', radix: 16),
);
void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: Colors.red.shade700,
      ),
    );
String? validateAmount(String? value) {
  final n = int.tryParse(value ?? '');
  if (n == null || n <= 0 || n > 1000000000000) {
    return 'Nhập số nguyên từ 1 đến 1.000.000.000.000 đồng';
  }
  return null;
}
