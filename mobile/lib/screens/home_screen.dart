import 'package:flutter/material.dart';
import '../core/session.dart';
import '../core/format.dart';
import '../widgets/summary_view.dart';
import 'editors.dart';

class HomeScreen extends StatefulWidget {
  final Session session;
  const HomeScreen({super.key, required this.session});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int tab = 0, total = 0, page = 1, generation = 0;
  String filter = 'all', query = '';
  bool loading = true, loadingMore = false, mutating = false;
  String? error;
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> categories = [], entries = [], budgets = [];
  static const titles = ['Tổng quan', 'Giao dịch', 'Ngân sách', 'Danh mục'];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Map<String, String> entryQuery(int p) => {
    'month': monthKey(month),
    'page': '$p',
    'limit': '30',
    if (filter != 'all') 'kind': filter,
    if (query.isNotEmpty) 'search': query,
  };
  Future<void> load() async {
    final current = ++generation;
    setState(() {
      loading = true;
      loadingMore = false;
      error = null;
    });
    try {
      final api = widget.session.api, m = monthKey(month);
      final results = await Future.wait([
        api.request('GET', '/categories'),
        api.request('GET', '/reports/summary', query: {'month': m}),
        api.request('GET', '/transactions', query: entryQuery(1)),
        api.request('GET', '/budgets', query: {'month': m}),
      ]);
      if (!mounted || current != generation) return;
      setState(() {
        categories = List<Map<String, dynamic>>.from(results[0]);
        summary = Map<String, dynamic>.from(results[1]);
        entries = List<Map<String, dynamic>>.from(results[2]['items']);
        total = results[2]['total'];
        page = 1;
        budgets = List<Map<String, dynamic>>.from(results[3]);
        loading = false;
      });
    } catch (e) {
      if (mounted && current == generation) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> more() async {
    final current = generation;
    setState(() => loadingMore = true);
    try {
      final data = await widget.session.api.request(
        'GET',
        '/transactions',
        query: entryQuery(page + 1),
      );
      if (!mounted || current != generation) return;
      setState(() {
        entries.addAll(List<Map<String, dynamic>>.from(data['items']));
        total = data['total'];
        page++;
      });
    } catch (e) {
      if (mounted && current == generation) showError(context, e);
    } finally {
      if (mounted && current == generation) setState(() => loadingMore = false);
    }
  }

  Future<void> openEditor(Widget editor) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => editor),
    );
    if (changed == true && mounted) await load();
  }

  Future<void> remove(String path, String name) async {
    if (mutating || !await confirmDelete(context, name) || !mounted) return;
    setState(() => mutating = true);
    try {
      await widget.session.api.request('DELETE', path);
      if (mounted) await load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  void changeMonth(int delta) {
    final next = DateTime(month.year, month.month + delta);
    if (next.year < 2000 || next.year > 2099) return;
    setState(() => month = next);
    load();
  }

  Future<void> pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099, 12, 31),
      helpText: 'Chọn ngày bất kỳ trong tháng muốn xem',
    );
    if (selected != null && mounted) {
      setState(() => month = DateTime(selected.year, selected.month));
      load();
    }
  }

  void add() {
    if (tab == 2) {
      openEditor(
        BudgetEditor(
          api: widget.session.api,
          categories: categories,
          month: monthKey(month),
        ),
      );
    } else if (tab == 3) {
      openEditor(CategoryEditor(api: widget.session.api));
    } else {
      openEditor(
        TransactionEditor(api: widget.session.api, categories: categories),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(titles[tab]),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
        PopupMenuButton<String>(
          tooltip: 'Tài khoản',
          onSelected: (value) async {
            if (value == 'logout') {
              try {
                await widget.session.logout();
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Text(widget.session.user?['name'] ?? ''),
            ),
            PopupMenuItem(
              enabled: false,
              child: Text(widget.session.user?['email'] ?? ''),
            ),
            const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              if (tab != 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Tháng trước',
                        onPressed: () => changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      TextButton.icon(
                        onPressed: pickMonth,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          'Tháng ${month.month.toString().padLeft(2, '0')}/${month.year}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tháng sau',
                        onPressed: () => changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: load,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          children: [
                            if (tab == 0)
                              SummaryView(summary: summary, budgets: budgets),
                            if (tab == 1) ...transactionWidgets(),
                            if (tab == 2) ...budgetWidgets(),
                            if (tab == 3) ...categoryWidgets(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
    floatingActionButton: loading || error != null || mutating
        ? null
        : FloatingActionButton.extended(
            onPressed: add,
            icon: const Icon(Icons.add),
            label: Text(
              tab == 2
                  ? 'Đặt ngân sách'
                  : tab == 3
                  ? 'Tạo danh mục'
                  : 'Thêm giao dịch',
            ),
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Tổng quan',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Giao dịch',
        ),
        NavigationDestination(
          icon: Icon(Icons.savings_outlined),
          selectedIcon: Icon(Icons.savings),
          label: 'Ngân sách',
        ),
        NavigationDestination(
          icon: Icon(Icons.category_outlined),
          selectedIcon: Icon(Icons.category),
          label: 'Danh mục',
        ),
      ],
    ),
  );
  List<Widget> transactionWidgets() => [
    TextField(
      controller: search,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm ghi chú hoặc danh mục',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Tìm kiếm',
          icon: const Icon(Icons.arrow_forward),
          onPressed: () {
            query = search.text.trim();
            load();
          },
        ),
      ),
      onSubmitted: (value) {
        query = value.trim();
        load();
      },
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      children: [
        for (final item in const {
          'all': 'Tất cả',
          'expense': 'Khoản chi',
          'income': 'Khoản thu',
        }.entries)
          ChoiceChip(
            label: Text(item.value),
            selected: filter == item.key,
            onSelected: (_) {
              setState(() => filter = item.key);
              load();
            },
          ),
      ],
    ),
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text('$total giao dịch phù hợp'),
    ),
    if (entries.isEmpty)
      const EmptyState(
        title: 'Chưa có giao dịch phù hợp',
        message: 'Thử đổi tháng, bộ lọc hoặc thêm một khoản thu/chi.',
      ),
    for (final entry in entries)
      Card(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: categoryColor(
                  entry['color'],
                ).withValues(alpha: 0.12),
                child: Icon(
                  entry['kind'] == 'income'
                      ? Icons.south_west
                      : Icons.north_east,
                  color: categoryColor(entry['color']),
                ),
              ),
              title: Text(
                entry['categoryName'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${displayDate(entry['occurredOn'])}${entry['note'].toString().isEmpty ? '' : '\n${entry['note']}'}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton<String>(
                enabled: !mutating,
                tooltip: 'Thao tác giao dịch',
                onSelected: (action) {
                  if (action == 'edit') {
                    openEditor(
                      TransactionEditor(
                        api: widget.session.api,
                        categories: categories,
                        entry: entry,
                      ),
                    );
                  } else {
                    remove('/transactions/${entry['id']}', 'giao dịch này');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
              onTap: () => openEditor(
                TransactionEditor(
                  api: widget.session.api,
                  categories: categories,
                  entry: entry,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${entry['kind'] == 'income' ? '+' : '−'}${money(entry['amount'])}',
                  style: TextStyle(
                    color: entry['kind'] == 'income'
                        ? Colors.teal
                        : Colors.deepOrange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    if (entries.length < total)
      Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton(
          onPressed: loadingMore ? null : more,
          child: Text(loadingMore ? 'Đang tải…' : 'Xem thêm'),
        ),
      ),
  ];
  List<Widget> budgetWidgets() => [
    const Text(
      'Đặt hạn mức chi tiêu cho từng danh mục. Hạn mức áp dụng riêng cho tháng đang chọn.',
    ),
    const SizedBox(height: 16),
    if (budgets.isEmpty)
      const EmptyState(
        title: 'Chưa đặt ngân sách tháng này',
        message: 'Chọn “Đặt ngân sách” để bắt đầu.',
        icon: Icons.savings_outlined,
      ),
    for (final b in budgets) budgetCard(b),
  ];
  Widget budgetCard(Map<String, dynamic> b) {
    final spent = amountOf(b['spent']),
        limit = amountOf(b['amount']),
        over = spent > limit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    b['categoryName'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !mutating,
                  tooltip: 'Thao tác ngân sách',
                  onSelected: (a) {
                    if (a == 'edit') {
                      openEditor(
                        BudgetEditor(
                          api: widget.session.api,
                          categories: categories,
                          month: monthKey(month),
                          budget: b,
                        ),
                      );
                    } else {
                      remove('/budgets/${b['id']}', 'ngân sách này');
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ],
            ),
            Text('${money(spent)} / ${money(limit)}'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (spent / limit).clamp(0, 1),
              color: over ? Colors.red : categoryColor(b['color']),
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Text(
              over
                  ? 'Vượt ${money(spent - limit)}'
                  : 'Còn ${money(limit - spent)}',
              style: TextStyle(
                color: over ? Colors.red.shade700 : Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> categoryWidgets() => [
    const Text(
      'Tạo danh mục để phân loại thu nhập và chi tiêu. Danh mục đang được dùng sẽ không thể xóa.',
    ),
    const SizedBox(height: 16),
    for (final kind in ['expense', 'income']) ...[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          kind == 'expense' ? 'Danh mục khoản chi' : 'Danh mục khoản thu',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      for (final c in categories.where((c) => c['kind'] == kind))
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: categoryColor(
                c['color'],
              ).withValues(alpha: 0.12),
              child: Icon(
                Icons.label_outline,
                color: categoryColor(c['color']),
              ),
            ),
            title: Text(c['name']),
            onTap: () => openEditor(
              CategoryEditor(api: widget.session.api, category: c),
            ),
            trailing: PopupMenuButton<String>(
              enabled: !mutating,
              tooltip: 'Thao tác danh mục',
              onSelected: (a) {
                if (a == 'edit') {
                  openEditor(
                    CategoryEditor(api: widget.session.api, category: c),
                  );
                } else {
                  remove('/categories/${c['id']}', 'danh mục “${c['name']}”');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
          ),
        ),
    ],
  ];
}
