import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tx_item.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/helpers.dart';
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
    if (raised)
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAlert(level));
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundIconButton(
                  icon: Icons.menu,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _RoundIconButton(
                      icon: _lastLevel > 0
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      onTap: () {
                        if (_budgetTotal <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Set a monthly budget to get alerts.',
                              ),
                            ),
                          );
                        } else {
                          _showAlert(_lastLevel);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your expenses smartly',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.deepPurple.shade50,
                  child: const Icon(
                    Icons.school,
                    size: 32,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Monthly Budget Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade300,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Budget',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'This Month',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '৳ ${_budgetSpent.toStringAsFixed(0)} / ৳ ${_budgetTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation(
                        progress >= 1
                            ? Colors.redAccent
                            : progress >= 0.8
                            ? Colors.orangeAccent
                            : Colors.greenAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _budgetTotal == 0
                            ? Icons.info_outline
                            : progress >= 1
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle,
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
                          ),
                        ),
                      ),
                    ],
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
                    icon: Icons.arrow_downward,
                    iconBg: Colors.green.shade50,
                    iconColor: Colors.green,
                    label: 'Total Expense',
                    value: _totalExpense,
                    valueColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.arrow_upward,
                    iconBg: Colors.blue.shade50,
                    iconColor: Colors.blue,
                    label: 'Total Income',
                    value: _totalIncome,
                    valueColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.savings_outlined,
                    iconBg: Colors.orange.shade50,
                    iconColor: Colors.orange,
                    label: 'Total Savings',
                    value: _totalSavings,
                    valueColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => _open(const ExpensesScreen()),
                  child: const Row(
                    children: [
                      Text('View All'),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.account_balance_wallet,
                    label: 'Add Expense',
                    bg: Colors.deepPurple.shade50,
                    iconColor: Colors.deepPurple,
                    onTap: () =>
                        _open(const AddTransactionScreen(isExpense: true)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.attach_money,
                    label: 'Add Income',
                    bg: Colors.green.shade50,
                    iconColor: Colors.green,
                    onTap: () =>
                        _open(const AddTransactionScreen(isExpense: false)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.track_changes,
                    label: 'Set Budget',
                    bg: Colors.red.shade50,
                    iconColor: Colors.red,
                    onTap: () => _open(const BudgetScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.bar_chart,
                    label: 'View Report',
                    bg: Colors.blue.shade50,
                    iconColor: Colors.blue,
                    onTap: () => _open(const ReportScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Expenses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Expenses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => _open(const ExpensesScreen()),
                  child: const Row(
                    children: [
                      Text('View All'),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _recentExpenses.isEmpty
                  ? Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No expenses yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add your first expense to see it here',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: List.generate(_recentExpenses.length, (index) {
                        final item = _recentExpenses[index];
                        final isLast = index == _recentExpenses.length - 1;
                        return Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (item['color'] as Color)
                                    .withOpacity(0.1),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: item['color'] as Color,
                                ),
                              ),
                              title: Text(item['title'] as String),
                              subtitle: Text(item['time'] as String),
                              trailing: Text(
                                '৳ ${item['amount']}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!isLast)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      }),
                    ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(const AddTransactionScreen(isExpense: true)),
        backgroundColor: Colors.deepPurple,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home,
              label: 'Home',
              selected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
            _NavItem(
              icon: Icons.receipt_long,
              label: 'Expenses',
              selected: _selectedTab == 1,
              onTap: () => _open(const ExpensesScreen()),
            ),
            const SizedBox(width: 40), // space for FAB
            _NavItem(
              icon: Icons.pie_chart_outline,
              label: 'Budget',
              selected: _selectedTab == 2,
              onTap: () => _open(const BudgetScreen()),
            ),
            _NavItem(
              icon: Icons.person_outline,
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

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      shape: const CircleBorder(),
      elevation: 1,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: iconBg,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '৳ ${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: 15,
            ),
          ),
          const Text(
            'This Month',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
    final color = selected ? Colors.deepPurple : Colors.grey;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
