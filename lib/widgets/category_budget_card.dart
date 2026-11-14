import 'package:flutter/material.dart';
import '../models/tx_item.dart';
import '../utils/helpers.dart';

/// Per-category monthly limits with progress and alerts.
class CategoryBudgetCard extends StatelessWidget {
  final List<TxItem> expenses;
  final DateTime month;
  final Map<String, double> limits;
  final Future<void> Function(String category, double limit) onSave;

  const CategoryBudgetCard({
    super.key,
    required this.expenses,
    required this.month,
    required this.limits,
    required this.onSave,
  });

  double _spent(String category) => expenses
      .where((e) => e.category == category && sameMonth(e.date, month))
      .fold(0.0, (s, e) => s + e.amount);

  Future<void> _openSheet(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LimitsSheet(limits: limits, onSave: onSave),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category limits saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final active = expenseCategories
        .where((c) => (limits[c] ?? 0) > 0)
        .toList();

    final alerts = <(String, Color, String)>[];
    for (final c in active) {
      final limit = limits[c]!;
      final spent = _spent(c);
      if (spent >= limit) {
        alerts.add((
          c,
          const Color(0xFFFF5D6C),
          '$c limit exceeded by ${tk(spent - limit)}',
        ));
      } else if (spent >= limit * 0.8) {
        alerts.add((
          c,
          const Color(0xFFF59E0B),
          '$c is at ${(spent / limit * 100).toStringAsFixed(0)}% of its limit',
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Category Limits',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: () => _openSheet(context),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Set Limits'),
                ),
              ],
            ),
            if (active.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'No category limits yet. Tap "Set Limits" to control spending per category, like Food or Transport.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.4),
              ),
            ] else ...[
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...alerts.map(
                  (a) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: a.$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: a.$2.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: a.$2, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.$3,
                            style: TextStyle(
                              color: a.$2,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              ...active.map((c) {
                final limit = limits[c]!;
                final spent = _spent(c);
                final pct = (spent / limit).clamp(0.0, 1.0);
                final color = spent >= limit
                    ? const Color(0xFFFF5D6C)
                    : spent >= limit * 0.8
                    ? const Color(0xFFF59E0B)
                    : categoryColor(c);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(categoryIcon(c), color: color, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  c,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${tk(spent)} / ${tk(limit)}',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 7,
                                color: color,
                                backgroundColor: color.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _LimitsSheet extends StatefulWidget {
  final Map<String, double> limits;
  final Future<void> Function(String category, double limit) onSave;
  const _LimitsSheet({required this.limits, required this.onSave});

  @override
  State<_LimitsSheet> createState() => _LimitsSheetState();
}

class _LimitsSheetState extends State<_LimitsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final c in expenseCategories)
        c: TextEditingController(
          text: (widget.limits[c] ?? 0) > 0
              ? widget.limits[c]!.toStringAsFixed(0)
              : '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      for (final c in expenseCategories) {
        final v = double.tryParse(_ctrls[c]!.text.trim()) ?? 0;
        final old = widget.limits[c] ?? 0;
        if (v != old) await widget.onSave(c, v);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your connection.')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Category Limits',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Monthly limit per category. Leave empty for no limit.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 16),
              ...expenseCategories.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _ctrls[c],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: c,
                      prefixIcon: Icon(categoryIcon(c), color: categoryColor(c)),
                      prefixText: '৳ ',
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      final n = double.tryParse(t);
                      if (n == null || n < 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Limits'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
