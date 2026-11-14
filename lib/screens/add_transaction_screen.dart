import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tx_item.dart';
import '../services/firestore_service.dart';
import '../utils/helpers.dart';

class AddTransactionScreen extends StatefulWidget {
  final bool isExpense;
  final TxItem? existing;

  const AddTransactionScreen({
    super.key,
    required this.isExpense,
    this.existing,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _service = FirestoreService();
  late String _category;
  late DateTime _date;
  bool _saving = false;

  List<String> get _categories =>
      widget.isExpense ? expenseCategories : incomeCategories;
  String get _col => widget.isExpense ? 'expenses' : 'incomes';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? _categories.first;
    if (!_categories.contains(_category)) _category = 'Other';
    _date = e?.date ?? DateTime.now();
    if (e != null) {
      _title.text = e.title;
      _amount.text = e.amount.toStringAsFixed(
        e.amount == e.amount.roundToDouble() ? 0 : 2,
      );
      _note.text = e.note;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final item = TxItem(
      id: widget.existing?.id ?? '',
      title: _title.text.trim(),
      amount: double.parse(_amount.text.trim()),
      category: _category,
      date: _date,
      note: _note.text.trim(),
    );
    try {
      if (widget.existing == null) {
        await _service.addTx(_col, item);
      } else {
        await _service.updateTx(_col, item);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final label = widget.isExpense ? 'Expense' : 'Income';
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A1A26) : Colors.white;
    final border = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.08);
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    final heroColors = widget.isExpense
        ? const [Color(0xFF7B5CFA), Color(0xFF4F2FE0)]
        : const [Color(0xFF2BD17E), Color(0xFF12945A)];

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit $label' : 'Add $label')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Amount hero
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
              child: Column(
                children: [
                  Text(
                    widget.isExpense
                        ? 'How much did you spend?'
                        : 'How much did you get?',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amount,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                      ),
                      prefixText: '৳ ',
                      prefixStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                      ),
                      errorStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null) return 'Enter a valid amount';
                      if (n <= 0) return 'Amount must be greater than 0';
                      if (n > 10000000) return 'Amount is too large';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Please enter a title';
                if (t.length > 60) return 'Title is too long (max 60)';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Category chips
            Text(
              'Category',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _categories.map((c) {
                final selected = c == _category;
                final color = categoryColor(c);
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _category = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.16) : surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? color : border,
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcon(c),
                          size: 18,
                          color: selected ? color : muted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? color : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Date
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEE, dd MMM yyyy').format(_date),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(editing ? 'Update $label' : 'Save $label'),
            ),
          ],
        ),
      ),
    );
  }
}
