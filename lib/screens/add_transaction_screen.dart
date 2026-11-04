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
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit $label' : 'Add $label')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Please enter a title';
                if (t.length > 60) return 'Title is too long (max 60)';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (৳)',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null) return 'Enter a valid amount';
                if (n <= 0) return 'Amount must be greater than 0';
                if (n > 10000000) return 'Amount is too large';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('dd MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(editing ? 'Update $label' : 'Save $label'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
