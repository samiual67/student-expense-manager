import 'package:flutter/material.dart';
import '../models/tx_item.dart';
import '../utils/helpers.dart';

class _Insight {
  final IconData icon;
  final Color color;
  final String text;
  const _Insight(this.icon, this.color, this.text);
}

/// Shows short smart messages about the student's spending.
/// Usage: InsightsCard(expenses: _expenses)
class InsightsCard extends StatelessWidget {
  final List<TxItem> expenses;
  const InsightsCard({super.key, required this.expenses});

  List<_Insight> _build() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final prevStart = today.subtract(const Duration(days: 13));

    double thisWeek = 0;
    double lastWeek = 0;
    final byCategory = <String, double>{};
    double monthTotal = 0;

    for (final e in expenses) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      if (!d.isBefore(weekStart) && !d.isAfter(today)) {
        thisWeek += e.amount;
      } else if (!d.isBefore(prevStart) && d.isBefore(weekStart)) {
        lastWeek += e.amount;
      }
      if (sameMonth(e.date, now)) {
        monthTotal += e.amount;
        byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      }
    }

    final list = <_Insight>[];

    // 1) Week vs last week
    if (thisWeek > 0 || lastWeek > 0) {
      if (lastWeek == 0) {
        list.add(
          _Insight(
            Icons.insights_rounded,
            const Color(0xFF3B82F6),
            'You spent ${tk(thisWeek)} in the last 7 days.',
          ),
        );
      } else {
        final pct = (thisWeek - lastWeek) / lastWeek * 100;
        if (pct >= 5) {
          list.add(
            _Insight(
              Icons.trending_up_rounded,
              const Color(0xFFFF5D6C),
              'Spending is up ${pct.toStringAsFixed(0)}% compared to last week.',
            ),
          );
        } else if (pct <= -5) {
          list.add(
            _Insight(
              Icons.trending_down_rounded,
              const Color(0xFF22C55E),
              'Nice! Spending is down ${pct.abs().toStringAsFixed(0)}% compared to last week.',
            ),
          );
        } else {
          list.add(
            _Insight(
              Icons.trending_flat_rounded,
              const Color(0xFF3B82F6),
              'Your spending is steady compared to last week.',
            ),
          );
        }
      }
    }

    // 2) Top category this month
    if (byCategory.isNotEmpty && monthTotal > 0) {
      final top = byCategory.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final share = top.value / monthTotal * 100;
      list.add(
        _Insight(
          categoryIcon(top.key),
          categoryColor(top.key),
          'Top spending this month: ${top.key} ${tk(top.value)} (${share.toStringAsFixed(0)}%).',
        ),
      );
    }

    // 3) Average per day this month
    if (monthTotal > 0) {
      list.add(
        _Insight(
          Icons.calendar_today_rounded,
          const Color(0xFF7C5CFA),
          'You spend about ${tk(monthTotal / now.day)} per day this month.',
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final insights = _build();
    if (insights.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A1A26) : Colors.white;
    final border = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Insights',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            children: List.generate(insights.length, (i) {
              final item = insights[i];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: item.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.text,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != insights.length - 1)
                    Divider(height: 1, color: border),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
