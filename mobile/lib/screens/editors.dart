import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/format.dart';

class TransactionEditor extends StatefulWidget {
  final Api api;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? entry;
  const TransactionEditor({
    super.key,
    required this.api,
    required this.categories,
    this.entry,
  });
  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount, note;
  late String kind, payment;
  String? categoryId;
  late DateTime date;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    amount = TextEditingController(text: e?['amount']?.toString() ?? '');
    note = TextEditingController(text: e?['note'] ?? '');
    kind = e?['kind'] ?? 'expense';
    payment = e?['paymentMethod'] ?? 'cash';
    categoryId = e?['categoryId'];
    date = e == null ? DateTime.now() : DateTime.parse(e['occurredOn']);
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.api.request(
        widget.entry == null ? 'POST' : 'PUT',
        widget.entry == null
            ? '/transactions'
            : '/transactions/${widget.entry!['id']}',
        body: {
          'kind': kind,
          'categoryId': categoryId,
          'amount': int.parse(amount.text),
          'occurredOn': dateKey(date),
          'note': note.text.trim(),
          'paymentMethod': payment,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.categories.where((c) => c['kind'] == kind).toList();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.entry == null ? 'Thêm giao dịch' : 'Sửa giao dịch',
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.editorWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      direction:
                          MediaQuery.sizeOf(context).width <
                                  AppLayout.metricBreakpoint &&
                              MediaQuery.textScalerOf(context).scale(16) > 24
                          ? Axis.vertical
                          : Axis.horizontal,
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Khoản chi'),
                          icon: Icon(Icons.arrow_upward),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Khoản thu'),
                          icon: Icon(Icons.arrow_downward),
                        ),
                      ],
                      selected: {kind},
                      onSelectionChanged: busy
                          ? null
                          : (s) => setState(() {
                              kind = s.first;
                              categoryId = null;
                            }),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    TextFormField(
                      controller: amount,
                      autofocus: widget.entry == null,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Số tiền',
                        suffixText: 'VND',
                        helperText: 'Ví dụ: nhập 50000 cho 50.000 đồng',
                      ),
                      validator: validateAmount,
                    ),
                    const SizedBox(height: AppSpace.xl),
                    DropdownButtonFormField<String>(
                      key: ValueKey(kind),
                      initialValue: categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: choices
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'],
                              child: Text(c['name']),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (v) => setState(() => categoryId = v),
                      validator: (v) =>
                          v == null ? 'Vui lòng chọn danh mục' : null,
                    ),
                    if (choices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpace.sm),
                        child: Text(
                          'Bạn cần tạo danh mục cùng loại ở màn hình Danh mục.',
                        ),
                      ),
                    const SizedBox(height: AppSpace.xl),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final value = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2099, 12, 31),
                              );
                              if (value != null && mounted) {
                                setState(() => date = value);
                              }
                            },
                      icon: const Icon(Icons.calendar_month),
                      label: Padding(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Text(
                          'Ngày giao dịch: ${displayDate(dateKey(date))}',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    DropdownButtonFormField<String>(
                      initialValue: payment,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Phương thức',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('Tiền mặt'),
                        ),
                        DropdownMenuItem(
                          value: 'bank',
                          child: Text('Chuyển khoản'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Khác')),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => payment = v!),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    TextFormField(
                      controller: note,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    FilledButton.icon(
                      onPressed: busy ? null : save,
                      icon: const Icon(Icons.check),
                      label: Padding(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Text(busy ? 'Đang lưu…' : 'Lưu giao dịch'),
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
  }
}

Future<bool> confirmDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có muốn xóa $name? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    ) ??
    false;

class CategoryEditor extends StatefulWidget {
  final Api api;
  final Map<String, dynamic>? category;
  const CategoryEditor({super.key, required this.api, this.category});
  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  late String kind, color;
  bool busy = false;
  static const colors = [
    '#0F766E',
    '#F97316',
    '#3B82F6',
    '#8B5CF6',
    '#EF4444',
    '#EC4899',
    '#059669',
    '#06B6D4',
  ];
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.category?['name'] ?? '');
    kind = widget.category?['kind'] ?? 'expense';
    color = widget.category?['color'] ?? colors.first;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.api.request(
        widget.category == null ? 'POST' : 'PUT',
        widget.category == null
            ? '/categories'
            : '/categories/${widget.category!['id']}',
        body: {'name': name.text.trim(), 'kind': kind, 'color': color},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Tạo danh mục' : 'Sửa danh mục'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.editorWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: name,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Tên danh mục',
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Vui lòng nhập tên'
                          : null,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    SegmentedButton<String>(
                      direction:
                          MediaQuery.sizeOf(context).width <
                                  AppLayout.metricBreakpoint &&
                              MediaQuery.textScalerOf(context).scale(16) > 24
                          ? Axis.vertical
                          : Axis.horizontal,
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Khoản chi'),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Khoản thu'),
                        ),
                      ],
                      selected: {kind},
                      onSelectionChanged: busy
                          ? null
                          : (s) => setState(() => kind = s.first),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    const Text('Màu nhận diện'),
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                      spacing: AppSpace.md,
                      runSpacing: AppSpace.md,
                      children: colors
                          .map(
                            (c) => Semantics(
                              label: 'Màu $c',
                              selected: color == c,
                              button: true,
                              child: InkWell(
                                onTap: busy
                                    ? null
                                    : () => setState(() => color = c),
                                borderRadius: AppShape.borderRadius,
                                child: CircleAvatar(
                                  backgroundColor: categoryColor(c),
                                  radius: AppLayout.controlSize / 2,
                                  child: color == c
                                      ? Icon(
                                          Icons.check,
                                          color: contentOn(categoryColor(c)),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    const Text(
                      'Danh mục đã có giao dịch hoặc ngân sách chỉ đổi được tên và màu; không đổi loại thu/chi.',
                    ),
                    const SizedBox(height: AppSpace.xl),
                    FilledButton(
                      onPressed: busy ? null : save,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Text(busy ? 'Đang lưu…' : 'Lưu danh mục'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BudgetEditor extends StatefulWidget {
  final Api api;
  final List<Map<String, dynamic>> categories;
  final String month;
  final Map<String, dynamic>? budget;
  const BudgetEditor({
    super.key,
    required this.api,
    required this.categories,
    required this.month,
    this.budget,
  });
  @override
  State<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<BudgetEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount;
  String? categoryId;
  bool busy = false;
  List<Map<String, dynamic>> get expenseCategories => widget.categories
      .where((c) => c['kind'] == 'expense')
      .toList();

  Map<String, dynamic>? get selectedCategory {
    for (final item in expenseCategories) {
      if (item['id'] == categoryId) return item;
    }
    return null;
  }
  @override
  void initState() {
    super.initState();
    amount = TextEditingController(
      text: widget.budget?['amount']?.toString() ?? '',
    );
    categoryId = widget.budget?['categoryId'];
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.api.request(
        'PUT',
        '/budgets',
        body: {
          'categoryId': categoryId,
          'month': widget.month,
          'amount': int.parse(amount.text),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final editing = widget.budget != null;
    final monthLabel = widget.month.split('-').reversed.join('/');
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(editing ? 'Sửa ngân sách' : 'Thêm ngân sách')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.editorWidth),
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.xl),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: scheme.primary,
                          child: Icon(
                            editing ? Icons.tune_rounded : Icons.savings_rounded,
                            color: scheme.onPrimary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                editing ? 'Điều chỉnh kế hoạch' : 'Lập kế hoạch chi tiêu',
                                style: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Thiết lập hạn mức cho tháng $monthLabel',
                                style: text.bodyMedium?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Thông tin ngân sách', style: text.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Chọn danh mục và nhập số tiền bạn dự định chi.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục chi tiêu',
                      prefixIcon: Icon(Icons.category_outlined),
                      helperText: 'Mỗi danh mục có một ngân sách trong tháng',
                    ),
                    items: expenseCategories
                        .map((c) => DropdownMenuItem<String>(
                              value: c['id'] as String,
                              child: Text(c['name'].toString(), overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: busy || editing
                        ? null
                        : (value) => setState(() => categoryId = value),
                    validator: (value) => value == null ? 'Vui lòng chọn danh mục' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: amount,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: validateAmount,
                    decoration: const InputDecoration(
                      labelText: 'Hạn mức chi tiêu',
                      hintText: 'Ví dụ: 2000000',
                      prefixIcon: Icon(Icons.payments_outlined),
                      suffixText: 'VND',
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: amount,
                    builder: (context, _) {
                      final entered = int.tryParse(amount.text) ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
  children: [
    Icon(
      Icons.visibility_outlined,
      size: 19,
      color: scheme.primary,
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        'Xem trước kế hoạch',
        style: text.titleSmall,
        softWrap: true,
      ),
    ),
  ],
),
                            const SizedBox(height: 12),
                            Text(
                              selectedCategory?['name']?.toString() ?? 'Chưa chọn danh mục',
                              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              money(entered),
                              style: text.headlineSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('Hạn mức tháng $monthLabel', style: text.bodySmall),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : save,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(busy ? 'Đang lưu…' : (editing ? 'Lưu thay đổi' : 'Tạo ngân sách')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hạn mức sẽ được lưu cho đúng danh mục và tháng đã chọn.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
