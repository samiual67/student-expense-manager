import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tx_item.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/helpers.dart';
import '../widgets/insights_card.dart';
import 'add_transaction_screen.dart';
import 'budget_screen.dart';
import 'expenses_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  final _service = FirestoreService();
  final List<StreamSubscription> _subs = [];
  final _now = DateTime.now();

  List<TxItem> _expenses = [];
  List<TxItem> _incomes = [];
  double _budgetTotal = 0;
  bool _gotExp = false, _gotInc = false, _gotBud = false;
  int _lastLevel = 0;

  double get _budgetSpent => sumMonth(_expenses, _now);
  double get _totalExpense => _budgetSpent;
  double get _totalIncome => sumMonth(_incomes, _now);
  double get _totalSavings => _totalIncome - _totalExpense;

  List<Map<String, dynamic>> get _recentExpenses => _expenses
      .take(5)
      .map(
        (e) => {
          'title': e.title,
          'time': '${e.category} • ${DateFormat('dd MMM').format(e.date)}',
          'amount': e.amount.toStringAsFixed(0),
          'icon': categoryIcon(e.category),
          'color': categoryColor(e.category),
        },
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _subs.add(
      _service.streamTx('expenses').listen((v) {
        setState(() {
          _expenses = v;
          _gotExp = true;
        });
        _checkAlert();
      }),
    );
    _subs.add(
      _service.streamTx('incomes').listen((v) {
        setState(() {
          _incomes = v;
          _gotInc = true;
        });
      }),
    );
    _subs.add(
      _service.streamBudget(_now).listen((v) {
        setState(() {
          _budgetTotal = v;
          _gotBud = true;
        });
        _checkAlert();
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _checkAlert() {
    if (!(_gotExp && _gotInc && _gotBud)) return;
    final level = alertLevel(_budgetSpent, _budgetTotal);
    final raised = level > _lastLevel;
    _lastLevel = level;
    if (raised) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAlert(level));
    }
  }

  void _showAlert(int level) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: level == 100 ? Colors.red : Colors.orange,
          size: 40,
        ),
        title: Text(level == 100 ? 'Budget exceeded' : 'Budget alert $level%'),
        content: Text(alertMessage(level)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    if (_budgetTotal <= 0) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surfaceOf(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderOf(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Set a monthly budget to see how much you can spend each day.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final daysInMonth = DateTime(_now.year, _now.month + 1, 0).day;
    final daysLeft = daysInMonth - _now.day + 1;
    final todaySpent = _expenses
        .where(
          (e) =>
              e.date.year == _now.year &&
              e.date.month == _now.month &&
              e.date.day == _now.day,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
    final beforeToday = _budgetSpent - todaySpent;
    final allowance = (_budgetTotal - beforeToday) / daysLeft;
    final leftToday = allowance - todaySpent;
    final progress = allowance > 0
        ? (todaySpent / allowance).clamp(0.0, 1.0)
        : 1.0;

    final color = leftToday <= 0
        ? const Color(0xFFFF5D6C)
        : leftToday < allowance * 0.3
        ? const Color(0xFFF59E0B)
        : const Color(0xFF22C55E);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.wb_sunny_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leftToday > 0
                          ? 'Safe to spend today'
                          : 'Daily limit reached',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '৳ ${(leftToday > 0 ? leftToday : 0).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysLeft days left',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent today ৳ ${todaySpent.toStringAsFixed(0)}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                'Daily limit ৳ ${(allowance > 0 ? allowance : 0).toStringAsFixed(0)}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Quick add items: title, amount (৳), category. Change these as you like.
  static const _quickItems = <(String, double, String)>[
    ('Rickshaw', 20, 'Transport'),
    ('Bus', 15, 'Transport'),
    ('Chai', 10, 'Food'),
    ('Snacks', 30, 'Food'),
    ('Lunch', 80, 'Food'),
    ('Recharge', 50, 'Mobile Recharge'),
  ];

  Future<void> _quickAdd(String title, double amount, String category) async {
    try {
      final id = await _service.addTxReturnId(
        'expenses',
        TxItem(
          id: '',
          title: title,
          amount: amount,
          category: category,
          date: DateTime.now(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Added $title ৳ ${amount.toStringAsFixed(0)}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _service.deleteTx('expenses', id),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add. Check your connection.')),
      );
    }
  }

  Widget _buildQuickAdd(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Quick Add',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'tap to add expense',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final (title, amount, category) = _quickItems[i];
              final color = categoryColor(category);
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _quickAdd(title, amount, category),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _surfaceOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _borderOf(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(categoryIcon(category), size: 18, color: color),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '৳${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final firstName = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName!.split(' ').first
        : 'Student';
    final progress = _budgetTotal > 0
        ? (_budgetSpent / _budgetTotal).clamp(0.0, 1.0)
        : 0.0;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundIconButton(
                  icon: Icons.menu_rounded,
                  onTap: () => _open(const SettingsScreen()),
                ),
                _RoundIconButton(
                  icon: _lastLevel > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  onTap: () {
                    if (_budgetTotal <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Set a monthly budget to get alerts.'),
                        ),
                      );
                    } else {
                      _showAlert(_lastLevel);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Greeting
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $firstName 👋',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your expenses smartly',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B6CFF), Color(0xFF5B3CF0)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    firstName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Monthly Budget Card
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B5CFA), Color(0xFF4F2FE0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C4DF6).withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -36,
                    top: -36,
                    child: Container(
                      height: 130,
                      width: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 50,
                    bottom: -56,
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Monthly Budget',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'This Month',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '৳ ${_budgetSpent.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '/ ৳ ${_budgetTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.25,
                            ),
                            valueColor: AlwaysStoppedAnimation(
                              progress >= 1
                                  ? Colors.redAccent
                                  : progress >= 0.8
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              _budgetTotal == 0
                                  ? Icons.info_outline
                                  : progress >= 1
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _budgetTotal == 0
                                    ? 'No budget set yet. Tap "Set Budget" to start.'
                                    : progress >= 1
                                    ? 'Budget exceeded!'
                                    : progress >= 0.8
                                    ? 'Careful! ${(progress * 100).toStringAsFixed(0)}% of budget used.'
                                    : 'Great! You are within your budget.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stat cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.south_west_rounded,
                    iconBg: Colors.transparent,
                    iconColor: const Color(0xFFFF5D6C),
                    label: 'Expense',
                    value: _totalExpense,
                    valueColor: const Color(0xFFFF5D6C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.north_east_rounded,
                    iconBg: Colors.transparent,
                    iconColor: const Color(0xFF22C55E),
                    label: 'Income',
                    value: _totalIncome,
                    valueColor: const Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.savings_outlined,
                    iconBg: Colors.transparent,
                    iconColor: const Color(0xFF3B82F6),
                    label: 'Savings',
                    value: _totalSavings,
                    valueColor: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSafeCard(context),
            const SizedBox(height: 24),
            _buildQuickAdd(context),
            const SizedBox(height: 24),
            InsightsCard(expenses: _expenses),
            const SizedBox(height: 28),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'Add Expense',
                    bg: Colors.transparent,
                    iconColor: const Color(0xFF7C5CFA),
                    onTap: () =>
                        _open(const AddTransactionScreen(isExpense: true)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Add Income',
                    bg: Colors.transparent,
                    iconColor: const Color(0xFF22C55E),
                    onTap: () =>
                        _open(const AddTransactionScreen(isExpense: false)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.track_changes_rounded,
                    label: 'Set Budget',
                    bg: Colors.transparent,
                    iconColor: const Color(0xFFFF5D6C),
                    onTap: () => _open(const BudgetScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.bar_chart_rounded,
                    label: 'View Report',
                    bg: Colors.transparent,
                    iconColor: const Color(0xFF3B82F6),
                    onTap: () => _open(const ReportScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Recent Expenses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Expenses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                TextButton(
                  onPressed: () => _open(const ExpensesScreen()),
                  child: const Row(
                    children: [
                      Text('View All'),
                      Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(
                vertical: _recentExpenses.isEmpty ? 36 : 6,
              ),
              decoration: BoxDecoration(
                color: _surfaceOf(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _borderOf(context)),
              ),
              child: _recentExpenses.isEmpty
                  ? Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 42,
                            color: muted,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No expenses yet',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add your first expense to see it here',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: List.generate(_recentExpenses.length, (index) {
                        final item = _recentExpenses[index];
                        final isLast = index == _recentExpenses.length - 1;
                        final color = item['color'] as Color;
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2,
                              ),
                              leading: Container(
                                height: 46,
                                width: 46,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: color,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                item['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                item['time'] as String,
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                              trailing: Text(
                                '- ৳ ${item['amount']}',
                                style: const TextStyle(
                                  color: Color(0xFFFF5D6C),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!isLast)
                              const Divider(
                                height: 1,
                                indent: 76,
                                endIndent: 16,
                              ),
                          ],
                        );
                      }),
                    ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: Container(
        height: 62,
        width: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B6CFF), Color(0xFF5B3CF0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C4DF6).withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _open(const AddTransactionScreen(isExpense: true)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 78,
        padding: EdgeInsets.zero,
        color: _surfaceOf(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
            _NavItem(
              icon: Icons.receipt_long_rounded,
              label: 'Expenses',
              selected: _selectedTab == 1,
              onTap: () => _open(const ExpensesScreen()),
            ),
            const SizedBox(width: 40), // space for FAB
            _NavItem(
              icon: Icons.pie_chart_outline_rounded,
              label: 'Budget',
              selected: _selectedTab == 2,
              onTap: () => _open(const BudgetScreen()),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              selected: _selectedTab == 3,
              onTap: () => _open(const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

Color _surfaceOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF1A1A26)
    : Colors.white;

Color _borderOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Colors.white10
    : Colors.black.withValues(alpha: 0.06);

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceOf(context),
      shape: CircleBorder(side: BorderSide(color: _borderOf(context))),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final double value;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: _surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderOf(context)),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '৳ ${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text('This Month', style: TextStyle(fontSize: 10, color: muted)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.bg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: _surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderOf(context)),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected
        ? primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
