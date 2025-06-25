// lib/screens/inventory_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/add_item_screen.dart';
import 'package:strefa_ciszy/screens/item_detail_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'customer_list_screen.dart';

class InventoryListScreen extends StatefulWidget {
  final bool isAdmin;
  const InventoryListScreen({super.key, required this.isAdmin});

  @override
  _InventoryListScreenState createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  String _search = '';
  String _category = '';
  List<String> _categories = [];
  late final TextEditingController _searchController;
  late final StreamSubscription<QuerySnapshot> _catSub;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _catSub = FirebaseFirestore.instance
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          setState(() {
            _categories = snap.docs.map((d) => d['name'] as String).toList();
          });
        });
  }

  @override
  void dispose() {
    _catSub.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _search = '';
      _category = '';
    });
  }

  Query<StockItem> get _stockQuery {
    Query<Map<String, dynamic>> base = FirebaseFirestore.instance.collection(
      'stock_items',
    );

    if (_category.isNotEmpty) {
      base = base.where('category', isEqualTo: _category);
    }

    base = base.orderBy('name');

    return base.withConverter<StockItem>(
      fromFirestore: (snap, _) => StockItem.fromMap(snap.data()!, snap.id),
      toFirestore: (item, _) => item.toMap(),
    );
  }

  Widget _buildCategoryChip(String? value, String label) {
    final selected = (value ?? '') == _category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = value ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inwentaryzacja'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Wyszukaj…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Resetuj filtr',
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetFilters,
                ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryChip(null, 'Wszystko'),
                ..._categories.map((cat) {
                  final label = cat[0].toUpperCase() + cat.substring(1);
                  return _buildCategoryChip(cat, label);
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<StockItem>>(
              stream: _stockQuery.snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final allItems = snap.data!.docs.map((d) => d.data()).toList();
                final queryLower = _search.toLowerCase();
                final filtered = queryLower.isEmpty
                    ? allItems
                    : allItems.where((item) {
                        final prod = item.producent?.toLowerCase() ?? '';
                        final name = item.name.toLowerCase();
                        return prod.contains(queryLower) ||
                            name.contains(queryLower);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Nie znaleziono produktów.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    return ListTile(
                      isThreeLine: true,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.producent ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(item.name, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      subtitle: Text(
                        '• ${item.quantity}'
                        '${item.unit != null ? ' ${item.unit}' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(itemId: item.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddItemScreen())),
        tooltip: 'Dodaj pozycja',
        child: const Icon(Icons.add),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.group),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Skanuj',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
