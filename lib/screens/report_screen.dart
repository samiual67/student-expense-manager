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

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_month),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                'Income: ${tk(income)}',
                style: const TextStyle(color: Colors.blue),
              ),
              Text(
                'Expense: ${tk(spent)}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Spending by Category',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (cats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No expenses this month')),
            )
          else ...[
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: cats.entries
                      .map(
                        (e) => PieChartSectionData(
                          value: e.value,
                          color: categoryColor(e.key),
                          radius: 70,
                          title:
                              '${(e.value / spent * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: cats.entries
                  .map(
                    (e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          color: categoryColor(e.key),
                        ),
                        const SizedBox(width: 6),
                        Text('${e.key} ${tk(e.value)}'),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Last 6 Months',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 12, height: 12, color: Colors.blue),
              const SizedBox(width: 4),
              const Text('Income'),
              const SizedBox(width: 14),
              Container(width: 12, height: 12, color: Colors.red),
              const SizedBox(width: 4),
              const Text('Expense'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barGroups: List.generate(
                  6,
                  (i) => BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: incTotals[i],
                        color: Colors.blue,
                        width: 10,
                      ),
                      BarChartRodData(
                        toY: expTotals[i],
                        color: Colors.red,
                        width: 10,
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
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 44),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('MMM').format(months[v.toInt()]),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _exporting ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(
                _exporting ? 'Creating PDF...' : 'Export Monthly Report (PDF)',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
