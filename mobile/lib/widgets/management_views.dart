import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'summary_view.dart';

typedef FinanceRecord = Map<String, dynamic>;

class TransactionsView extends StatelessWidget {
  final List<FinanceRecord> entries;
  final FinanceRecord summary;
  final int total;
  final String filter;
  final TextEditingController search;
  final ValueChanged<String> onSearch, onFilter;
  final ValueChanged<FinanceRecord> onEdit, onDelete;
  final VoidCallback onMore;
  final bool mutating, loadingMore;
  const TransactionsView({
    super.key,
    required this.entries,
    required this.summary,
    required this.total,
    required this.filter,
    required this.search,
    required this.onSearch,
    required this.onFilter,
    required this.onEdit,
    required this.onDelete,
    required this.onMore,
    required this.mutating,
    required this.loadingMore,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final groups = <String, List<FinanceRecord>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry['occurredOn'], () => []).add(entry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroPanel(
          icon: Icons.swap_vert_rounded,
          title: 'Dòng tiền trong tháng',
          subtitle: 'Tổng thu – chi của tháng đang chọn.',
          child: _AdaptiveColumns(
            children: [
              _Figure(
                label: 'Thu nhập',
                value: money(summary['income']),
                color: c.tertiary,
                icon: Icons.south_west,
              ),
              _Figure(
                label: 'Chi tiêu',
                value: money(summary['expense']),
                color: c.secondary,
                icon: Icons.north_east,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: onSearch,
          decoration: InputDecoration(
            labelText: 'Tìm giao dịch',
            hintText: 'Ghi chú hoặc tên danh mục',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    search.clear();
                    onSearch('');
                  },
                ),
                IconButton(
                  tooltip: 'Tìm kiếm',
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => onSearch(search.text),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in const {
              'all': 'Tất cả',
              'expense': 'Khoản chi',
              'income': 'Khoản thu',
            }.entries)
              ChoiceChip(
                selected: filter == option.key,
                showCheckmark: false,
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: filter == option.key ? c.primary : c.outlineVariant,
                ),
                labelStyle: TextStyle(
                  color: filter == option.key ? c.primary : c.onSurfaceVariant,
                ),
                avatar: Icon(
                  option.key == 'all'
                      ? Icons.swap_vert
                      : option.key == 'income'
                      ? Icons.south_west
                      : Icons.north_east,
                  size: 17,
                  color: filter == option.key ? c.primary : c.onSurfaceVariant,
                ),
                label: Text(option.value),
                onSelected: (_) => onFilter(option.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '$total giao dịch phù hợp',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        if (entries.isEmpty)
          const EmptyState(
            title: 'Chưa có giao dịch phù hợp',
            message: 'Thử đổi tháng, bộ lọc hoặc thêm một khoản thu/chi.',
          ),
        for (final group in groups.entries) ...[
          _SectionHeading(
            title: displayDate(group.key),
            detail: '${group.value.length} giao dịch',
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < group.value.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _TransactionRow(
                    entry: group.value[i],
                    enabled: !mutating,
                    onEdit: () => onEdit(group.value[i]),
                    onDelete: () => onDelete(group.value[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (entries.length < total)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton.icon(
              onPressed: loadingMore ? null : onMore,
              icon: const Icon(Icons.expand_more),
              label: Text(loadingMore ? 'Đang tải…' : 'Xem thêm'),
            ),
          ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final FinanceRecord entry;
  final bool enabled;
  final VoidCallback onEdit, onDelete;
  const _TransactionRow({
    required this.entry,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final income = entry['kind'] == 'income';
    final color = income ? c.tertiary : c.secondary;
    final note = entry['note']?.toString() ?? '';
    return InkWell(
      onTap: enabled ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _CategoryIcon(
                name: entry['categoryName'],
                color: categoryColor(entry['color']),
                income: income,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
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
                      '${entry['categoryName']} · ${entry['paymentMethod'] == 'bank'
                          ? 'Chuyển khoản'
                          : entry['paymentMethod'] == 'other'
                          ? 'Khác'
                          : 'Tiền mặt'}',
                      style: type.bodySmall?.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${income ? '+' : '−'}${money(entry['amount'])}',
                      style: type.titleMedium?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ),
            _Actions(
              tooltip: 'Thao tác giao dịch',
              enabled: enabled,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetsView extends StatelessWidget {
  final List<FinanceRecord> budgets;
  final ValueChanged<FinanceRecord> onEdit, onDelete;
  final bool mutating;
  const BudgetsView({
    super.key,
    required this.budgets,
    required this.onEdit,
    required this.onDelete,
    required this.mutating,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final limit = budgets.fold<int>(0, (sum, b) => sum + amountOf(b['amount']));
    final spent = budgets.fold<int>(0, (sum, b) => sum + amountOf(b['spent']));
    final over = budgets
        .where((b) => amountOf(b['spent']) > amountOf(b['amount']))
        .length;
    final remaining = limit - spent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroPanel(
          icon: Icons.savings_outlined,
          title: remaining < 0 ? 'Vượt tổng hạn mức' : 'Ngân sách còn lại',
          subtitle:
              'Trong ${budgets.length} danh mục đã đặt ngân sách tháng này.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Amount(
                value: money(remaining.abs()),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: remaining < 0 ? c.error : c.primary,
                ),
              ),
              const SizedBox(height: 16),
              _AdaptiveColumns(
                minWidth: 165,
                children: [
                  _Figure(
                    label: 'Đã chi',
                    value: money(spent),
                    color: c.secondary,
                  ),
                  _Figure(
                    label: 'Tổng hạn mức',
                    value: money(limit),
                    color: c.onSurface,
                  ),
                ],
              ),
              if (budgets.isNotEmpty) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: limit <= 0 ? 0 : (spent / limit).clamp(0, 1),
                  minHeight: 8,
                  color: remaining < 0 ? c.error : c.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  over > 0
                      ? '$over danh mục vượt hạn mức · Cần điều chỉnh chi tiêu'
                      : 'Theo dõi từng danh mục để giữ chi tiêu trong kế hoạch.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: over > 0 ? c.error : c.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        _SectionHeading(
          title: 'Kế hoạch chi tiêu',
          detail: '${budgets.length} danh mục',
        ),
        if (budgets.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(
                  text: '${budgets.length - over} trong kế hoạch',
                  color: c.primary,
                ),
                if (over > 0)
                  _Badge(text: '$over vượt hạn mức', color: c.error),
              ],
            ),
          ),
        ],
        if (budgets.isEmpty)
          const EmptyState(
            title: 'Chưa đặt ngân sách tháng này',
            message: 'Chọn “Đặt ngân sách” để tạo hạn mức đầu tiên.',
            icon: Icons.savings_outlined,
          )
        else
          _AdaptiveColumns(
            minWidth: 290,
            children: [
              for (final budget in budgets)
                _BudgetCard(
                  budget: budget,
                  enabled: !mutating,
                  onEdit: () => onEdit(budget),
                  onDelete: () => onDelete(budget),
                ),
            ],
          ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final FinanceRecord budget;
  final bool enabled;
  final VoidCallback onEdit, onDelete;
  const _BudgetCard({
    required this.budget,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final spent = amountOf(budget['spent']), limit = amountOf(budget['amount']);
    final over = spent > limit;
    final ratio = limit <= 0 ? 0.0 : spent / limit;
    final color = over
        ? c.error
        : ratio >= .8
        ? c.secondary
        : c.primary;
    final status = over
        ? 'Vượt hạn mức'
        : ratio >= .8
        ? 'Sắp chạm hạn mức'
        : 'Trong kế hoạch';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _CategoryIcon(
                    name: budget['categoryName'],
                    color: categoryColor(budget['color']),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      budget['categoryName'],
                      style: type.titleMedium,
                    ),
                  ),
                  _Actions(
                    tooltip: 'Thao tác ngân sách',
                    enabled: enabled,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _Badge(text: status, color: color),
                  Text(
                    '${(ratio * 100).round()}% đã dùng',
                    style: type.bodySmall?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0, 1),
                  minHeight: 10,
                  backgroundColor: c.surfaceContainerHighest,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              _AdaptiveColumns(
                minWidth: 165,
                children: [
                  _Figure(
                    label: 'Đã chi',
                    value: money(spent),
                    color: c.onSurface,
                  ),
                  _Figure(
                    label: 'Hạn mức',
                    value: money(limit),
                    color: c.onSurfaceVariant,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Icon(
                    over ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      over
                          ? 'Vượt ${money(spent - limit)}'
                          : 'Còn ${money(limit - spent)}',
                      style: type.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoriesView extends StatelessWidget {
  final List<FinanceRecord> categories;
  final ValueChanged<FinanceRecord> onEdit, onDelete;
  final bool mutating;
  const CategoriesView({
    super.key,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    required this.mutating,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final income = categories.where((item) => item['kind'] == 'income').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroPanel(
          icon: Icons.category_outlined,
          title: 'Sắp xếp dòng tiền',
          subtitle: 'Mỗi khoản thu, chi đều có một nơi để ghi nhớ.',
          child: _AdaptiveColumns(
            children: [
              _Figure(
                label: 'Danh mục chi',
                value: '${categories.length - income}',
                color: c.secondary,
                icon: Icons.north_east,
              ),
              _Figure(
                label: 'Danh mục thu',
                value: '$income',
                color: c.tertiary,
                icon: Icons.south_west,
              ),
            ],
          ),
        ),
        for (final kind in ['expense', 'income']) ...[
          _SectionHeading(
            title: kind == 'expense'
                ? 'Danh mục khoản chi'
                : 'Danh mục khoản thu',
            detail:
                '${categories.where((item) => item['kind'] == kind).length} danh mục',
          ),
          if (!categories.any((item) => item['kind'] == kind))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                kind == 'expense'
                    ? 'Chưa có danh mục chi. Tạo danh mục để phân loại khoản chi.'
                    : 'Chưa có danh mục thu. Tạo danh mục cho các nguồn thu nhập.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            )
          else
            _AdaptiveColumns(
              minWidth: 145,
              children: [
                for (final category in categories.where(
                  (item) => item['kind'] == kind,
                ))
                  Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: mutating ? null : () => onEdit(category),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _CategoryIcon(
                                  name: category['name'],
                                  color: categoryColor(category['color']),
                                  income: kind == 'income',
                                ),
                                const Spacer(),
                                _Actions(
                                  tooltip: 'Thao tác danh mục',
                                  enabled: !mutating,
                                  onEdit: () => onEdit(category),
                                  onDelete: () => onDelete(category),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              category['name'],
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              kind == 'income' ? 'Khoản thu' : 'Khoản chi',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: c.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
        const SizedBox(height: 20),
        Text(
          'Chạm vào danh mục để chỉnh sửa. Danh mục đã có giao dịch sẽ không thể xóa.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget child;
  const _HeroPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: AppShape.borderRadius,
        border: Border.all(color: c.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.surfaceContainerHighest, c.surfaceContainerLow],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: c.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData? icon;
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      _Amount(
        value: value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    ],
  );
}

class _Amount extends StatelessWidget {
  final String value;
  final TextStyle? style;
  const _Amount({required this.value, this.style});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: value,
    child: Text(value, style: style),
  );
}

// Wrap cards by measured width rather than using a fixed grid aspect ratio.
class _AdaptiveColumns extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  const _AdaptiveColumns({required this.children, this.minWidth = 125});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
      final count = largeText
          ? 1
          : ((box.maxWidth + 12) / (minWidth + 12)).floor().clamp(
              1,
              children.length.clamp(1, 3),
            );
      final width = (box.maxWidth - (count - 1) * 12) / count;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _SectionHeading extends StatelessWidget {
  final String title, detail;
  const _SectionHeading({required this.title, required this.detail});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(
          detail,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Actions extends StatelessWidget {
  final String tooltip;
  final bool enabled;
  final VoidCallback onEdit, onDelete;
  const _Actions({
    required this.tooltip,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: tooltip,
    enabled: enabled,
    onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 10),
            Text('Sửa'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18),
            SizedBox(width: 10),
            Text('Xóa'),
          ],
        ),
      ),
    ],
  );
}

class _CategoryIcon extends StatelessWidget {
  final String name;
  final Color color;
  final bool income;
  const _CategoryIcon({
    required this.name,
    required this.color,
    this.income = false,
  });
  @override
  Widget build(BuildContext context) {
    final lower = name.toLowerCase();
    final icon = lower.contains('ăn') || lower.contains('uống')
        ? Icons.restaurant_outlined
        : lower.contains('mua')
        ? Icons.shopping_bag_outlined
        : lower.contains('chuyển') || lower.contains('xe')
        ? Icons.directions_car_outlined
        : lower.contains('nhà')
        ? Icons.home_outlined
        : lower.contains('lương')
        ? Icons.work_outline
        : income
        ? Icons.south_west_rounded
        : Icons.sell_outlined;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
