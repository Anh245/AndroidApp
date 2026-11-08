import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/format.dart';
import '../widgets/summary_view.dart';
import '../widgets/management_views.dart';
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
  List<Map<String, dynamic>> categories = [],
      entries = [],
      budgets = [],
      recentEntries = [];
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
        api.request(
          'GET',
          '/transactions',
          query: {'month': m, 'page': '1', 'limit': '3'},
        ),
      ]);
      if (!mounted || current != generation) return;
      setState(() {
        categories = List<Map<String, dynamic>>.from(results[0]);
        summary = Map<String, dynamic>.from(results[1]);
        entries = List<Map<String, dynamic>>.from(results[2]['items']);
        total = results[2]['total'];
        page = 1;
        budgets = List<Map<String, dynamic>>.from(results[3]);
        recentEntries = List<Map<String, dynamic>>.from(results[4]['items']);
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SỔ CHI TIÊU',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(titles[tab]),
        ],
      ),
      toolbarHeight: 80,
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
          constraints: const BoxConstraints(maxWidth: AppLayout.contentWidth),
          child: Column(
            children: [
              if (tab != 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.xs,
                    AppSpace.lg,
                    AppSpace.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Tháng trước',
                        onPressed: () => changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Flexible(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                          ),
                          onPressed: pickMonth,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            'Tháng ${month.month}, ${month.year}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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
                          padding: const EdgeInsets.all(AppSpace.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(error!, textAlign: TextAlign.center),
                              const SizedBox(height: AppSpace.lg),
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
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.lg,
                            AppSpace.sm,
                            AppSpace.lg,
                            AppSpace.lg,
                          ),
                          children: [
                            if (tab == 0)
                              SummaryView(
                                summary: summary,
                                budgets: budgets,
                                recentEntries: recentEntries,
                                onViewAll: () => setState(() => tab = 1),
                                onEntryTap: (entry) => openEditor(
                                  TransactionEditor(
                                    api: widget.session.api,
                                    categories: categories,
                                    entry: entry,
                                  ),
                                ),
                              ),
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
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!loading && error == null)
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.contentWidth,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('primary-add-action'),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onPressed: mutating ? null : add,
                      icon: const Icon(Icons.add),
                      label: Text(
                        tab == 2
                            ? 'Đặt ngân sách'
                            : tab == 3
                            ? 'Tạo danh mục'
                            : 'Thêm giao dịch',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
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
      ],
    ),
  );
  List<Widget> transactionWidgets() => [
    TransactionsView(
      entries: entries,
      summary: summary,
      total: total,
      filter: filter,
      search: search,
      mutating: mutating,
      loadingMore: loadingMore,
      onMore: more,
      onSearch: (value) {
        query = value.trim();
        load();
      },
      onFilter: (value) {
        setState(() => filter = value);
        load();
      },
      onEdit: editTransaction,
      onDelete: (entry) =>
          remove('/transactions/${entry['id']}', 'giao dịch này'),
    ),
  ];

  void editTransaction(Map<String, dynamic> entry) => openEditor(
    TransactionEditor(
      api: widget.session.api,
      categories: categories,
      entry: entry,
    ),
  );

  List<Widget> budgetWidgets() => [
    BudgetsView(
      budgets: budgets,
      mutating: mutating,
      onEdit: (budget) => openEditor(
        BudgetEditor(
          api: widget.session.api,
          categories: categories,
          month: monthKey(month),
          budget: budget,
        ),
      ),
      onDelete: (budget) => remove('/budgets/${budget['id']}', 'ngân sách này'),
    ),
  ];

  List<Widget> categoryWidgets() => [
    CategoriesView(
      categories: categories,
      mutating: mutating,
      onEdit: (category) => openEditor(
        CategoryEditor(api: widget.session.api, category: category),
      ),
      onDelete: (category) => remove(
        '/categories/${category['id']}',
        'danh mục “${category['name']}”',
      ),
    ),
  ];
}
