import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tx_item.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(_uid).collection(name);

  // col = 'expenses' or 'incomes'
  Stream<List<TxItem>> streamTx(String col) => _col(col)
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(TxItem.fromDoc).toList());

  Future<void> addTx(String col, TxItem t) => _col(col).add(t.toMap());

  Future<void> updateTx(String col, TxItem t) =>
      _col(col).doc(t.id).update(t.toMap());

  Future<void> deleteTx(String col, String id) => _col(col).doc(id).delete();

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Stream<double> streamBudget(DateTime month) => _col('budgets')
      .doc(monthKey(month))
      .snapshots()
      .map((d) => ((d.data()?['amount'] ?? 0) as num).toDouble());

  Future<void> setBudget(DateTime month, double amount) =>
      _col('budgets').doc(monthKey(month)).set({
        'amount': amount,
        'month': monthKey(month),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<Map<String, dynamic>?> streamGoal() =>
      _col('goals').doc('main').snapshots().map((d) => d.data());

  Future<void> setGoal(String title, double target) =>
      _col('goals').doc('main').set({
        'title': title,
        'target': target,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
