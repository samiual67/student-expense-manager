import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tx_item.dart';
import '../services/firestore_service.dart';
import '../utils/helpers.dart';
import '../widgets/category_budget_card.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _service = FirestoreService();
  final _month = DateTime.now();
  final _budgetCtrl = TextEditingController();
  final _goalTitleCtrl = TextEditingController();
  final _goalTargetCtrl = TextEditingController();
  final _budgetKey = GlobalKey<FormState>();
  final _goalKey = GlobalKey<FormState>();
  final List<StreamSubscription> _subs = [];

  List<TxItem> _expenses = [];
  List<TxItem> _incomes = [];
  double _budget = 0;
  Map<String, double> _catLimits = {};
  double _goalTarget = 0;
  String _goalTitle = '';
  bool _budgetFilled = false;
  bool _goalFilled = false;

  @override
  void initState() {
    super.initState();
    _subs.add(
      _service
          .streamTx('expenses')
          .listen((v) => setState(() => _expenses = v)),
    );
    _subs.add(
      _service.streamTx('incomes').listen((v) => setState(() => _incomes = v)),
    );
    _subs.add(
      _service.streamBudget(_month).listen((v) {
        setState(() => _budget = v);
        if (!_budgetFilled) {
          _budgetFilled = true;
          if (v > 0) _budgetCtrl.text = v.toStringAsFixed(0);
        }
      }),
    );
    _subs.add(
      _service
          .streamCategoryBudgets(_month)
          .listen((v) => setState(() => _catLimits = v)),
    );
    _subs.add(
      _service.streamGoal().listen((g) {
        setState(() {
          _goalTitle = (g?['title'] ?? '') as String;
          _goalTarget = ((g?['target'] ?? 0) as num).toDouble();
        });
        if (!_goalFilled) {
          _goalFilled = true;
          if (g != null) {
            _goalTitleCtrl.text = _goalTitle;
            _goalTargetCtrl.text = _goalTarget.toStringAsFixed(0);
          }
        }
      }),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _budgetCtrl.dispose();
    _goalTitleCtrl.dispose();
    _goalTargetCtrl.dispose();
    super.dispose();
  }

  String? _amountValidator(String? v) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter a valid amount';
    if (n <= 0) return 'Amount must be greater than 0';
    if (n > 100000000) return 'Amount is too large';
    return null;
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _saveBudget() async {
    if (!_budgetKey.currentState!.validate()) return;
    try {
      await _service.setBudget(_month, double.parse(_budgetCtrl.text.trim()));
      if (mounted) _snack('Budget saved');
    } catch (_) {
      if (mounted) _snack('Could not save budget. Try again.');
    }
  }

  Future<void> _saveGoal() async {
    if (!_goalKey.currentState!.validate()) return;
    try {
      await _service.setGoal(
        _goalTitleCtrl.text.trim(),
        double.parse(_goalTargetCtrl.text.trim()),
      );
      if (mounted) _snack('Savings goal saved');
    } catch (_) {
      if (mounted) _snack('Could not save goal. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final spent = sumMonth(_expenses, _month);
    final income = sumMonth(_incomes, _month);
    final monthSavings = income - spent;
    final totalSavings = sumAll(_incomes) - sumAll(_expenses);
    final progress = _budget > 0 ? (spent / _budget).clamp(0.0, 1.0) : 0.0;
    final level = alertLevel(spent, _budget);
    final goalProgress = _goalTarget > 0
        ? (totalSavings / _goalTarget).clamp(0.0, 1.0)
        : 0.0;

    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    const green = Color(0xFF22C55E);
    const red = Color(0xFFFF5D6C);
    const blue = Color(0xFF3B82F6);

    final heroColors = level == 100
        ? const [Color(0xFFFF6B7A), Color(0xFFD62F45)]
        : level >= 80
        ? const [Color(0xFFFFA64D), Color(0xFFE8751A)]
        : const [Color(0xFF7B5CFA), Color(0xFF4F2FE0)];

    return Scaffold(
      appBar: AppBar(title: const Text('Budget & Savings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Hero summary
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: heroColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: heroColors.first.withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _budget > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Budget • ${DateFormat('MMMM yyyy').format(_month)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          SizedBox(
                            height: 100,
                            width: 100,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 10,
                                  strokeCap: StrokeCap.round,
                                  color: Colors.white,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    '${(spent / _budget * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Spent',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tk(spent),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                ),
                                Text(
                                  'of ${tk(_budget)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${tk((_budget - spent).abs())} ${spent > _budget ? 'over' : 'left'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(
                            level == 0
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alertMessage(level),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No budget set for this month yet. Set one below.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Set budget
          Form(
            key: _budgetKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set Monthly Budget',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Budget amount (৳)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: _amountValidator,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _saveBudget,
                      child: const Text('Save Budget'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          CategoryBudgetCard(
            expenses: _expenses,
            month: _month,
            limits: _catLimits,
            onSave: (cat, v) => _service.setCategoryBudget(_month, cat, v),
          ),
          const SizedBox(height: 16),

          // Savings tracker
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Savings Tracker',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  _row(
                    Icons.north_east_rounded,
                    'Income this month',
                    tk(income),
                    blue,
                  ),
                  _row(
                    Icons.south_west_rounded,
                    'Expense this month',
                    tk(spent),
                    red,
                  ),
                  const Divider(height: 24),
                  _row(
                    Icons.savings_outlined,
                    'Saved this month',
                    '${monthSavings < 0 ? '-' : ''}${tk(monthSavings.abs())}',
                    monthSavings >= 0 ? green : red,
                  ),
                  _row(
                    Icons.account_balance_wallet_outlined,
                    'Total savings (all time)',
                    '${totalSavings < 0 ? '-' : ''}${tk(totalSavings.abs())}',
                    totalSavings >= 0 ? green : red,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Savings goal
          Form(
            key: _goalKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Savings Goal',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _goalTitleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Goal (e.g. New laptop)',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Please enter a goal name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _goalTargetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Target amount (৳)',
                        prefixIcon: Icon(Icons.track_changes_rounded),
                      ),
                      validator: _amountValidator,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _saveGoal,
                      child: const Text('Save Goal'),
                    ),
                    if (_goalTarget > 0) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _goalTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${tk(totalSavings < 0 ? 0 : totalSavings)} / ${tk(_goalTarget)}',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: goalProgress,
                          minHeight: 12,
                          color: goalProgress >= 1 ? green : scheme.primary,
                          backgroundColor: scheme.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        goalProgress >= 1
                            ? 'Goal reached! 🎉'
                            : '${(goalProgress * 100).toStringAsFixed(0)}% complete',
                        style: TextStyle(
                          color: goalProgress >= 1 ? green : muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}
