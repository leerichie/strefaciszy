// lib/repositories/value_lists_repo.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ValueListsRepo {
  final _db = FirebaseFirestore.instance;
  late final Stream<List<String>> categories;
  late final Stream<List<String>> producers;
  late final Stream<List<String>> models;

  ValueListsRepo() {
    categories = _db
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => (d['name'] as String).trim()).toList());

    final stockStream = _db.collection('stock_items').snapshots();

    producers = stockStream.map((s) {
      final set = <String>{};
      for (final d in s.docs) {
        final p = (d['producent'] ?? '').toString().trim();
        if (p.isNotEmpty) set.add(p);
      }
      final list = set.toList()..sort();
      return list;
    });

    models = stockStream.map((s) {
      final set = <String>{};
      for (final d in s.docs) {
        final n = (d['name'] ?? '').toString().trim();
        if (n.isNotEmpty) set.add(n);
      }
      final list = set.toList()..sort();
      return list;
    });
  }
}
