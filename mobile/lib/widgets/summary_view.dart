import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
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
    padding: const EdgeInsets.symmetric(
      vertical: AppSpace.empty,
      horizontal: AppSpace.xl,
    ),
    child: Column(
      children: [
        Icon(
          icon,
          size: AppLayout.emptyIconSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpace.lg),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpace.sm),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class SummaryView extends StatelessWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> budgets, recentEntries;
  final ValueChanged<Map<String, dynamic>>? onEntryTap;
  final VoidCallback? onViewAll;
  const SummaryView({
    super.key,
    required this.summary,
    required this.budgets,
    this.recentEntries = const [],
    this.onEntryTap,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final categories = List<Map<String, dynamic>>.from(summary['byCategory']);
    final trend = List<Map<String, dynamic>>.from(summary['trend']);
    final expense = amountOf(summary['expense']);
    final over = budgets
        .where((b) => amountOf(b['spent']) > amountOf(b['amount']))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('monthly-summary'),
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            borderRadius: AppShape.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.surfaceContainerHighest, c.surfaceContainerLow],
            ),
            border: Border.all(color: c.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Chênh lệch tháng', style: type.bodyMedium),
              const SizedBox(height: AppSpace.xs),
              _Money(
                summary['balance'],
                style: type.headlineMedium?.copyWith(color: c.primary),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Divider(height: 1),
              ),
              LayoutBuilder(
                builder: (context, box) {
                  final stacked =
                      box.maxWidth < 250 ||
                      MediaQuery.textScalerOf(context).scale(16) > 24;
                  final income = _metric(
                    context,
                    'Thu nhập',
                    summary['income'],
                    c.tertiary,
                    Icons.arrow_upward,
                  );
                  final outgoing = _metric(
                    context,
                    'Chi tiêu',
                    summary['expense'],
                    c.secondary,
                    Icons.arrow_downward,
                  );
                  if (stacked) {
                    return Column(
                      children: [income, const SizedBox(height: 12), outgoing],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: income),
                      Container(
                        width: 1,
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: c.outlineVariant,
                      ),
                      Expanded(child: outgoing),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        _panel(
          context,
          title: 'Chi theo danh mục',
          child: categories.isEmpty
              ? const EmptyState(
                  title: 'Chưa có khoản chi',
                  message: 'Thêm giao dịch để xem phân bổ chi tiêu.',
                )
              : LayoutBuilder(
                  builder: (context, box) {
                    final stacked =
                        box.maxWidth < 250 ||
                        MediaQuery.textScalerOf(context).scale(16) > 24;
                    final chart = Semantics(
                      label:
                          'Tổng chi tiêu ${money(expense)}. Chi tiết từng danh mục ở bên cạnh.',
                      child: ExcludeSemantics(
                        child: SizedBox(
                          key: const ValueKey('category-ring'),
                          width: stacked ? 140 : 116,
                          height: stacked ? 140 : 116,
                          child: CustomPaint(
                            painter: _ExpenseRing(
                              categories,
                              expense,
                              c.surfaceContainerHighest,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(26),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: money(expense),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _chartAmount(expense),
                                          style: type.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Chi tiêu',
                                        style: type.bodySmall,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    final legend = Column(
                      key: const ValueKey('category-legend'),
                      children: [
                        for (var i = 0; i < categories.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpace.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 5, right: 8),
                                decoration: BoxDecoration(
                                  color: categoryColor(categories[i]['color']),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      categories[i]['name'],
                                      style: type.bodySmall?.copyWith(
                                        height: 1.2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    _Money(
                                      categories[i]['amount'],
                                      style: type.bodySmall?.copyWith(
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Text(
                                '${expense == 0 ? 0 : (amountOf(categories[i]['amount']) / expense * 100).round()}%',
                                style: type.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                    if (stacked) {
                      return Column(
                        children: [chart, const SizedBox(height: 16), legend],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        chart,
                        const SizedBox(width: 12),
                        Expanded(child: legend),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSpace.md),
        _panel(
          context,
          title: 'Giao dịch gần đây',
          action: TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Xem tất cả'),
          ),
          child: recentEntries.isEmpty
              ? const EmptyState(
                  title: 'Chưa có giao dịch',
                  message: 'Thêm khoản thu hoặc chi đầu tiên của tháng.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < recentEntries.length; i++) ...[
                      if (i > 0) const Divider(height: 12),
                      _recentRow(context, recentEntries[i]),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          '${summary['count']} giao dịch • Chênh lệch tháng chưa bao gồm số dư đầu kỳ.',
          style: type.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        if (over > 0) ...[
          const SizedBox(height: AppSpace.md),
          Card(
            color: c.secondaryContainer,
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: c.secondary),
              title: Text('$over danh mục đã vượt ngân sách'),
              subtitle: const Text('Mở mục Ngân sách để xem chi tiết.'),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.md),
        Card(
          child: ExpansionTile(
            title: Text('Thu – chi 6 tháng', style: type.titleMedium),
            subtitle: const Text('Xem xu hướng thu nhập và chi tiêu'),
            childrenPadding: const EdgeInsets.all(AppSpace.lg),
            children: [
              const Text('Xanh bạc hà: thu nhập • Hồng: chi tiêu'),
              const SizedBox(height: 16),
              for (final item in trend) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item['month'].toString().split('-').reversed.join('/'),
                  ),
                ),
                const SizedBox(height: 8),
                _trendBar(context, item['income'], trend, c.tertiary),
                const SizedBox(height: 8),
                _trendBar(context, item['expense'], trend, c.secondary),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? action,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (action == null)
            Text(title, style: Theme.of(context).textTheme.titleMedium)
          else
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                action,
              ],
            ),
          const SizedBox(height: AppSpace.md),
          child,
        ],
      ),
    ),
  );

  Widget _metric(
    BuildContext context,
    String label,
    dynamic value,
    Color color,
    IconData icon,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 30,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            _Money(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _recentRow(BuildContext context, Map<String, dynamic> entry) {
    final c = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final income = entry['kind'] == 'income';
    final color = income ? c.tertiary : c.secondary;
    final note = entry['note']?.toString() ?? '';
    final amount = '${income ? '+' : '−'}${money(entry['amount'])}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onEntryTap == null ? null : () => onEntryTap!(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: LayoutBuilder(
          builder: (context, box) {
            final stacked =
                MediaQuery.textScalerOf(context).scale(16) > 24 ||
                amount.length > 17;
            final value = Text(
              amount,
              style: type.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            );
            return Row(
              children: [
                Container(
                  width: 34,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    income ? Icons.south_west : Icons.receipt_long_outlined,
                    color: c.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.isEmpty ? entry['categoryName'] : note,
                        style: type.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        displayDate(entry['occurredOn']),
                        style: type.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      if (stacked) value,
                    ],
                  ),
                ),
                if (!stacked) ...[const SizedBox(width: 8), value],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _trendBar(
    BuildContext context,
    dynamic value,
    List<Map<String, dynamic>> trend,
    Color color,
  ) {
    final maxValue = trend.fold<int>(
      1,
      (m, t) =>
          math.max(m, math.max(amountOf(t['income']), amountOf(t['expense']))),
    );
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: (amountOf(value) / maxValue).clamp(0, 1),
            color: color,
            minHeight: 8,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            money(value),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// Keep exact amounts available to assistive technology and on long press.
class _Money extends StatelessWidget {
  final dynamic value;
  final TextStyle? style;
  const _Money(this.value, {this.style});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: money(value),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(money(value), style: style),
    ),
  );
}

String _chartAmount(int value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(2).replaceAll('.', ',')} tỷ ₫';
  }
  if (value >= 100000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} tr ₫';
  }
  return money(value);
}

class _ExpenseRing extends CustomPainter {
  final List<Map<String, dynamic>> categories;
  final int total;
  final Color track;
  _ExpenseRing(this.categories, this.total, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(12);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawOval(rect, paint..color = track);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final category in categories) {
      final sweep = amountOf(category['amount']) / total * math.pi * 2;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start + 0.015,
        math.max(0, sweep - 0.03),
        false,
        paint..color = categoryColor(category['color']),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpenseRing oldDelegate) =>
      oldDelegate.categories != categories ||
      oldDelegate.total != total ||
      oldDelegate.track != track;
}
