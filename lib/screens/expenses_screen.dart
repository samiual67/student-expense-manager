import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tx_item.dart';
import '../services/firestore_service.dart';
import '../utils/helpers.dart';
import 'add_transaction_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _service = FirestoreService();
  late Stream<List<TxItem>> _stream;
  bool _isExpense = true;
  String _query = '';
  String _category = 'All';
  String _sort = 'Newest';
  DateTime? _month;

  static const _sorts = ['Newest', 'Oldest', 'Amount: High', 'Amount: Low'];

  String get _col => _isExpense ? 'expenses' : 'incomes';

  @override
  void initState() {
    super.initState();
    _stream = _service.streamTx(_col);
  }

  void _toggle(bool isExpense) {
    setState(() {
      _isExpense = isExpense;
      _category = 'All';
      _stream = _service.streamTx(_col);
    });
  }

  List<TxItem> _apply(List<TxItem> all) {
    var list = all.where((e) {
      if (_category != 'All' && e.category != _category) return false;
      if (_month != null && !sameMonth(e.date, _month!)) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!e.title.toLowerCase().contains(q) &&
            !e.note.toLowerCase().contains(q) &&
            !e.amount.toString().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
    switch (_sort) {
      case 'Oldest':
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'Amount: High':
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Amount: Low':
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      default:
        list.sort((a, b) => b.date.compareTo(a.date));
    }
    return list;
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pick any day in the month',
    );
    if (picked != null)
      setState(() => _month = DateTime(picked.year, picked.month));
  }

  Future<bool> _confirmDelete(TxItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete "${item.title}" (${tk(item.amount)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await _service.deleteTx(_col, item.id);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _isExpense ? expenseCategories : incomeCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(isExpense: _isExpense),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Expenses')),
                ButtonSegment(value: false, label: Text('Income')),
              ],
              selected: {_isExpense},
              onSelectionChanged: (s) => _toggle(s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search title, note or amount',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ['All', ...cats]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sort',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _sorts
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _sort = v ?? 'Newest'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    _month == null
                        ? 'All months'
                        : DateFormat('MMMM yyyy').format(_month!),
                  ),
                  onPressed: _pickMonth,
                ),
                if (_month != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _month = null),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TxItem>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('Could not load data. Check your connection.'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = _apply(snap.data!);
                if (list.isEmpty) {
                  return const Center(child: Text('Nothing found'));
                }
                final total = sumAll(list);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${list.length} records'),
                          Text(
                            'Total: ${tk(total)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = list[i];
                          final color = categoryColor(item.category);
                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (_) => _confirmDelete(item),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.1),
                                child: Icon(
                                  categoryIcon(item.category),
                                  color: color,
                                ),
                              ),
                              title: Text(item.title),
                              subtitle: Text(
                                '${item.category} • ${DateFormat('dd MMM yyyy').format(item.date)}',
                              ),
                              trailing: Text(
                                tk(item.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isExpense ? Colors.red : Colors.green,
                                ),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddTransactionScreen(
                                    isExpense: _isExpense,
                                    existing: item,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
