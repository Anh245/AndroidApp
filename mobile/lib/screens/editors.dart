import 'package:flutter/material.dart';
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
            constraints: const BoxConstraints(maxWidth: 650),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
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
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 20),
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
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Bạn cần tạo danh mục cùng loại ở màn hình Danh mục.',
                        ),
                      ),
                    const SizedBox(height: 20),
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
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Ngày giao dịch: ${displayDate(dateKey(date))}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: payment,
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
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: note,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy ? null : save,
                      icon: const Icon(Icons.check),
                      label: Padding(
                        padding: const EdgeInsets.all(12),
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
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
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
                    const SizedBox(height: 20),
                    const Text('Màu nhận diện'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
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
                                borderRadius: BorderRadius.circular(24),
                                child: CircleAvatar(
                                  backgroundColor: categoryColor(c),
                                  radius: 24,
                                  child: color == c
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Danh mục đã có giao dịch hoặc ngân sách chỉ đổi được tên và màu; không đổi loại thu/chi.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : save,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Ngân sách tháng')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tháng ${widget.month.split('-').reversed.join('/')}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục chi tiêu',
                      ),
                      items: widget.categories
                          .where((c) => c['kind'] == 'expense')
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'],
                              child: Text(c['name']),
                            ),
                          )
                          .toList(),
                      onChanged: busy || widget.budget != null
                          ? null
                          : (v) => setState(() => categoryId = v),
                      validator: (v) => v == null ? 'Chọn danh mục' : null,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: validateAmount,
                      decoration: const InputDecoration(
                        labelText: 'Hạn mức chi tiêu',
                        suffixText: 'VND',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mỗi danh mục có một hạn mức trong tháng. Lưu lại sẽ cập nhật hạn mức đã có.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : save,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(busy ? 'Đang lưu…' : 'Lưu ngân sách'),
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
