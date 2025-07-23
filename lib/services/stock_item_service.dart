// lib/services/stock_item_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strefa_ciszy/utils/search_utils.dart';
import '../services/storage_service.dart';

class StockItemService {
  final _db = FirebaseFirestore.instance;
  final _storage = StorageService();

  Future<void> ensureCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final q = await _db
        .collection('categories')
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (q.docs.isEmpty) {
      await _db.collection('categories').add({'name': trimmed});
    }
  }

  Future<String> addItem({
    required String name,
    required String sku,
    required String barcode,
    required String producent,
    required String category,
    required int quantity,
    required String unit,
    required String location,
    File? imageFile,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final col = _db.collection('stock_items');
    final docRef = await col.add({
      'name': name,
      'nameFold': normalize(name),
      'sku': sku,
      'skuFold': normalize(sku),
      'category': category,
      'categoryFold': normalize(category),
      'barcode': barcode,
      'producent': producent,
      'producentFold': normalize(producent),
      'quantity': quantity,
      'unit': unit,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });

    await ensureCategory(category);

    if (imageFile != null) {
      final url = await _storage.uploadStockFile(docRef.id, imageFile);
      await docRef.update({'imageUrl': url});
    }
    return docRef.id;
  }

  Future<void> updateItem({
    required String docId,
    required String name,
    required String sku,
    required String barcode,
    required String producent,
    required String category,
    required int quantity,
    required String unit,
    required String location,
    File? imageFile,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _db.collection('stock_items').doc(docId);

    await ref.update({
      'name': name,
      'nameFold': normalize(name),
      'sku': sku,
      'skuFold': normalize(sku),
      'barcode': barcode,
      'producent': producent,
      'producentFold': normalize(producent),
      'category': category,
      'categoryFold': normalize(category),
      'quantity': quantity,
      'unit': unit,
      'location': location,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });

    await ensureCategory(category);

    if (imageFile != null) {
      final url = await _storage.uploadStockFile(docId, imageFile);
      await ref.update({'imageUrl': url});
    }
  }
}
