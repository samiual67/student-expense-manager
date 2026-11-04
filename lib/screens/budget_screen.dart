import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tx_item.dart';
import '../services/firestore_service.dart';
import '../utils/helpers.dart';

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
    final barColor = level == 100
        ? Colors.red
        : level >= 80
        ? Colors.orange
        : Colors.green;
    final goalProgress = _goalTarget > 0
        ? (totalSavings / _goalTarget).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget & Savings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _budgetKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Budget • ${DateFormat('MMMM yyyy').format(_month)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Budget amount (৳)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _amountValidator,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _saveBudget,
                      child: const Text('Save Budget'),
                    ),
                    const SizedBox(height: 16),
                    if (_budget > 0) ...[
                      Text('${tk(spent)} spent of ${tk(_budget)}'),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          color: barColor,
                          backgroundColor: barColor.withOpacity(0.15),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(spent / _budget * 100).toStringAsFixed(0)}% used • ${tk((_budget - spent).abs())} ${spent > _budget ? 'over' : 'left'}',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            level == 0
                                ? Icons.check_circle
                                : Icons.warning_amber_rounded,
                            color: barColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alertMessage(level),
                              style: TextStyle(
                                color: barColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      const Text('No budget set for this month yet.'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Savings Tracker',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _row('Income this month', tk(income), Colors.blue),
                  _row('Expense this month', tk(spent), Colors.red),
                  const Divider(),
                  _row(
                    'Saved this month',
                    '${monthSavings < 0 ? '-' : ''}${tk(monthSavings.abs())}',
                    monthSavings >= 0 ? Colors.green : Colors.red,
                  ),
                  _row(
                    'Total savings (all time)',
                    '${totalSavings < 0 ? '-' : ''}${tk(totalSavings.abs())}',
                    totalSavings >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _goalKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Savings Goal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _goalTitleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Goal (e.g. New laptop)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Please enter a goal name'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _goalTargetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Target amount (৳)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _amountValidator,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _saveGoal,
                      child: const Text('Save Goal'),
                    ),
                    if (_goalTarget > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        '$_goalTitle: ${tk(totalSavings < 0 ? 0 : totalSavings)} / ${tk(_goalTarget)}',
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: goalProgress,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        goalProgress >= 1
                            ? 'Goal reached! 🎉'
                            : '${(goalProgress * 100).toStringAsFixed(0)}% complete',
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

  Widget _row(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
