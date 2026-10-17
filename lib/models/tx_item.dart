import 'package:cloud_firestore/cloud_firestore.dart';

class TxItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String note;

  TxItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
  });

  factory TxItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TxItem(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      amount: ((d['amount'] ?? 0) as num).toDouble(),
      category: (d['category'] ?? 'Other') as String,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: (d['note'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'category': category,
        'date': Timestamp.fromDate(date),
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}