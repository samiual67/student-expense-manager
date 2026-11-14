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
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A1A26) : Colors.white;
    final border = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.08);
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final amountColor = _isExpense
        ? const Color(0xFFFF5D6C)
        : const Color(0xFF22C55E);

    Widget toggleItem(String text, bool value) {
      final selected = _isExpense == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => _toggle(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : muted,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B6CFF), Color(0xFF5B3CF0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C4DF6).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(isExpense: _isExpense),
            ),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
      body: Column(
        children: [
          // Expenses / Income toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  toggleItem('Expenses', true),
                  toggleItem('Income', false),
                ],
              ),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search title, note or amount',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),

          // Category chips
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cats.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = i == 0 ? 'All' : cats[i - 1];
                final selected = _category == c;
                final color = i == 0 ? scheme.primary : categoryColor(c);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _category = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.16) : surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? color : border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        if (i != 0) ...[
                          Icon(
                            categoryIcon(c),
                            size: 16,
                            color: selected ? color : muted,
                          ),
                          const SizedBox(width: 6),
                        ],
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
              },
            ),
          ),

          // Month + sort
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickMonth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _month == null
                              ? 'All months'
                              : DateFormat('MMMM yyyy').format(_month!),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_month != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() => _month = null),
                  ),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  itemBuilder: (_) => _sorts
                      .map((s) => PopupMenuItem(value: s, child: Text(s)))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sort_rounded, size: 18, color: muted),
                        const SizedBox(width: 6),
                        Text(
                          _sort,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 52, color: muted),
                        const SizedBox(height: 10),
                        const Text(
                          'Nothing found',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try a different filter or add a new record',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                final total = sumAll(list);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${list.length} records',
                            style: TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Total: ${tk(total)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: amountColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final item = list[i];
                          final color = categoryColor(item.category);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Dismissible(
                              key: ValueKey(item.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 22),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (_) => _confirmDelete(item),
                              child: Material(
                                color: surface,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddTransactionScreen(
                                        isExpense: _isExpense,
                                        existing: item,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          height: 48,
                                          width: 48,
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Icon(
                                            categoryIcon(item.category),
                                            color: color,
                                            size: 23,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${item.category} • ${DateFormat('dd MMM yyyy').format(item.date)}',
                                                style: TextStyle(
                                                  color: muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_isExpense ? '-' : '+'} ${tk(item.amount)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: amountColor,
                                          ),
                                        ),
                                      ],
                                    ),
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
