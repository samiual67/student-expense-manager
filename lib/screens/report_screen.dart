import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/tx_item.dart';
import '../services/firestore_service.dart';
import '../utils/helpers.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _service = FirestoreService();
  final List<StreamSubscription> _subs = [];
  List<TxItem> _expenses = [];
  List<TxItem> _incomes = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _exporting = false;

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
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Map<String, double> _byCategory(List<TxItem> items) {
    final map = <String, double>{};
    for (final e in items.where((e) => sameMonth(e.date, _month))) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Future<void> _exportPdf() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF export works on the Android app.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final label = DateFormat('MMMM yyyy').format(_month);
      final monthExp =
          _expenses.where((e) => sameMonth(e.date, _month)).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      final spent = sumMonth(_expenses, _month);
      final income = sumMonth(_incomes, _month);
      final cats = _byCategory(_expenses).entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Student Expense Report - $label',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text('Total Income: Tk ${income.toStringAsFixed(0)}'),
            pw.Text('Total Expense: Tk ${spent.toStringAsFixed(0)}'),
            pw.Text('Savings: Tk ${(income - spent).toStringAsFixed(0)}'),
            pw.SizedBox(height: 14),
            pw.Text(
              'Spending by Category',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (cats.isEmpty)
              pw.Text('No expenses this month.')
            else
              pw.TableHelper.fromTextArray(
                headers: ['Category', 'Amount (Tk)', '%'],
                data: cats
                    .map(
                      (e) => [
                        e.key,
                        e.value.toStringAsFixed(0),
                        '${(e.value / spent * 100).toStringAsFixed(0)}%',
                      ],
                    )
                    .toList(),
              ),
            pw.SizedBox(height: 14),
            pw.Text(
              'All Expenses',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (monthExp.isEmpty)
              pw.Text('No expenses this month.')
            else
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Title', 'Category', 'Amount (Tk)'],
                data: monthExp
                    .map(
                      (e) => [
                        DateFormat('dd MMM').format(e.date),
                        e.title,
                        e.category,
                        e.amount.toStringAsFixed(0),
                      ],
                    )
                    .toList(),
              ),
          ],
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/expense_report_${FirestoreService.monthKey(_month)}.pdf',
      );
      await file.writeAsBytes(await doc.save());
      await OpenFile.open(file.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the PDF. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _byCategory(_expenses);
    final spent = cats.values.fold(0.0, (a, b) => a + b);
    final income = sumMonth(_incomes, _month);
    final savings = income - spent;

    // last 6 months ending at selected month
    final months = List.generate(
      6,
      (i) => DateTime(_month.year, _month.month - 5 + i),
    );
    final expTotals = months.map((m) => sumMonth(_expenses, m)).toList();
    final incTotals = months.map((m) => sumMonth(_incomes, m)).toList();
    final maxY =
        [...expTotals, ...incTotals, 100.0].reduce((a, b) => a > b ? a : b) *
        1.2;

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A1A26) : Colors.white;
    final border = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.08);
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    const incomeColor = Color(0xFF3B82F6);
    const expenseColor = Color(0xFFFF5D6C);
    const savingsColor = Color(0xFF22C55E);

    final sortedCats = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Widget summaryCard(String label, double value, Color color, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${value < 0 ? '-' : ''}${tk(value.abs())}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget legendDot(String text, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: muted)),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // Month switcher
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _shift(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Summary cards
          Row(
            children: [
              summaryCard(
                'Income',
                income,
                incomeColor,
                Icons.north_east_rounded,
              ),
              const SizedBox(width: 10),
              summaryCard(
                'Expense',
                spent,
                expenseColor,
                Icons.south_west_rounded,
              ),
              const SizedBox(width: 10),
              summaryCard(
                'Savings',
                savings,
                savingsColor,
                Icons.savings_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Spending by category
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spending by Category',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (cats.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.pie_chart_outline_rounded,
                              size: 44,
                              color: muted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No expenses this month',
                              style: TextStyle(color: muted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 68,
                              sections: sortedCats
                                  .map(
                                    (e) => PieChartSectionData(
                                      value: e.value,
                                      color: categoryColor(e.key),
                                      radius: 30,
                                      showTitle: false,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Total spent',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tk(spent),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...sortedCats.map((e) {
                      final color = categoryColor(e.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                categoryIcon(e.key),
                                color: color,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: (e.value / spent).clamp(0.0, 1.0),
                                      minHeight: 6,
                                      color: color,
                                      backgroundColor: color.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  tk(e.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${(e.value / spent * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Last 6 months
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Last 6 Months',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          legendDot('Income', incomeColor),
                          const SizedBox(width: 12),
                          legendDot('Expense', expenseColor),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) =>
                              FlLine(color: border, strokeWidth: 1),
                        ),
                        barGroups: List.generate(
                          6,
                          (i) => BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(
                                toY: incTotals[i],
                                color: incomeColor,
                                width: 11,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                              BarChartRodData(
                                toY: expTotals[i],
                                color: expenseColor,
                                width: 11,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (v, meta) => Text(
                                NumberFormat.compact().format(v),
                                style: TextStyle(fontSize: 10, color: muted),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MMM').format(months[v.toInt()]),
                                  style: TextStyle(fontSize: 11, color: muted),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _exporting ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Text(
              _exporting ? 'Creating PDF...' : 'Export Monthly Report (PDF)',
            ),
          ),
        ],
      ),
    );
  }
}
