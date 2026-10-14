import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/format.dart';

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.receipt_long_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Column(
      children: [
        Icon(icon, size: 56, color: Colors.blueGrey),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class SummaryView extends StatelessWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> budgets;
  const SummaryView({super.key, required this.summary, required this.budgets});
  @override
  Widget build(BuildContext context) {
    final categories = List<Map<String, dynamic>>.from(summary['byCategory']);
    final trend = List<Map<String, dynamic>>.from(summary['trend']);
    final expense = amountOf(summary['expense']);
    final over = budgets
        .where((b) => amountOf(b['spent']) > amountOf(b['amount']))
        .length;
    final maxValue = trend.fold<int>(
      1,
      (m, t) =>
          math.max(m, math.max(amountOf(t['income']), amountOf(t['expense']))),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF115E59), Color(0xFF0F766E)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHÊNH LỆCH THU – CHI THÁNG',
                style: TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(summary['balance']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${summary['count']} giao dịch • Chưa bao gồm số dư đầu kỳ',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric(
                context,
                'Tổng thu',
                summary['income'],
                Colors.teal,
                constraints.maxWidth > 380
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                Icons.south_west,
              ),
              _metric(
                context,
                'Tổng chi',
                summary['expense'],
                Colors.deepOrange,
                constraints.maxWidth > 380
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                Icons.north_east,
              ),
            ],
          ),
        ),
        if (over > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              color: const Color(0xFFFFF1E9),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_amber,
                  color: Colors.deepOrange,
                ),
                title: Text('$over danh mục đã vượt ngân sách'),
                subtitle: const Text('Mở mục Ngân sách để xem chi tiết.'),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Chi tiêu theo danh mục',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          const EmptyState(
            title: 'Chưa có khoản chi',
            message: 'Thêm giao dịch để xem phân bổ chi tiêu.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: categories.map((c) {
                  final fraction = expense == 0
                      ? 0.0
                      : amountOf(c['amount']) / expense;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(money(c['amount'])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: fraction.clamp(0, 1),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          color: categoryColor(c['color']),
                          backgroundColor: Colors.grey.shade100,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(fraction * 100).toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Thu – chi 6 tháng',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Xanh: thu nhập  •  Cam: chi tiêu'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: trend
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            t['month'].toString().split('-').reversed.join('/'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          _bar(t['income'], maxValue, Colors.teal),
                          const SizedBox(height: 6),
                          _bar(t['expense'], maxValue, Colors.deepOrange),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bar(dynamic value, int maxValue, Color color) => Row(
    children: [
      Expanded(
        child: LinearProgressIndicator(
          value: (amountOf(value) / maxValue).clamp(0, 1),
          color: color,
          backgroundColor: Colors.grey.shade100,
          minHeight: 10,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 125,
        child: Text(
          money(value),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
  Widget _metric(
    BuildContext context,
    String label,
    dynamic value,
    Color color,
    double width,
    IconData icon,
  ) => SizedBox(
    width: width,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                money(value),
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
