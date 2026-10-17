import 'package:flutter/material.dart';
import '../models/tx_item.dart';

const expenseCategories = [
  'Food',
  'Transport',
  'Study',
  'Mobile Recharge',
  'Shopping',
  'Health',
  'Entertainment',
  'Other',
];

const incomeCategories = [
  'Pocket Money',
  'Part-time Job',
  'Scholarship',
  'Gift',
  'Other',
];

IconData categoryIcon(String c) {
  switch (c) {
    case 'Food':
      return Icons.restaurant;
    case 'Transport':
      return Icons.directions_bus;
    case 'Study':
      return Icons.menu_book;
    case 'Mobile Recharge':
      return Icons.phone_android;
    case 'Shopping':
      return Icons.shopping_bag;
    case 'Health':
      return Icons.medical_services;
    case 'Entertainment':
      return Icons.movie;
    case 'Pocket Money':
      return Icons.account_balance_wallet;
    case 'Part-time Job':
      return Icons.work;
    case 'Scholarship':
      return Icons.school;
    case 'Gift':
      return Icons.card_giftcard;
    default:
      return Icons.category;
  }
}

Color categoryColor(String c) {
  switch (c) {
    case 'Food':
      return Colors.orange;
    case 'Transport':
      return Colors.blue;
    case 'Study':
      return Colors.deepPurple;
    case 'Mobile Recharge':
      return Colors.teal;
    case 'Shopping':
      return Colors.pink;
    case 'Health':
      return Colors.red;
    case 'Entertainment':
      return Colors.amber.shade700;
    case 'Pocket Money':
      return Colors.green;
    case 'Part-time Job':
      return Colors.indigo;
    case 'Scholarship':
      return Colors.cyan;
    case 'Gift':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}

String tk(double v) => '৳ ${v.toStringAsFixed(0)}';

bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

double sumMonth(List<TxItem> items, DateTime month) => items
    .where((e) => sameMonth(e.date, month))
    .fold(0.0, (s, e) => s + e.amount);

double sumAll(List<TxItem> items) => items.fold(0.0, (s, e) => s + e.amount);

/// Returns 0, 80, 90 or 100 depending on how much of the budget is used.
int alertLevel(double spent, double budget) {
  if (budget <= 0) return 0;
  final p = spent / budget;
  if (p >= 1) return 100;
  if (p >= 0.9) return 90;
  if (p >= 0.8) return 80;
  return 0;
}

String alertMessage(int level) {
  switch (level) {
    case 100:
      return 'Budget exceeded! You have spent more than your monthly budget.';
    case 90:
      return 'Warning: you have used 90% of your monthly budget.';
    case 80:
      return 'Heads up: you have used 80% of your monthly budget.';
    default:
      return 'You are within your budget.';
  }
}
