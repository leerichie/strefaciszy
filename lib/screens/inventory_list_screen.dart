// lib/screens/inventory_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/add_item_screen.dart';
import 'package:strefa_ciszy/screens/item_detail_screen.dart';

class InventoryListScreen extends StatefulWidget {
  final bool isAdmin;
  const InventoryListScreen({Key? key, required this.isAdmin})
    : super(key: key);

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

  /// Returns a Query<StockItem> that applies category + prefix‐search + name ordering.
  Query<StockItem> get _stockQuery {
    // Start with a Query so we can reassign after .where()
    Query<Map<String, dynamic>> base = FirebaseFirestore.instance.collection(
      'stock_items',
    );

    if (_category.isNotEmpty) {
      base = base.where('category', isEqualTo: _category);
    }

    // Firestore requires you orderBy before startAt/endAt
    base = base.orderBy('name');

    if (_search.isNotEmpty) {
      base = base.startAt([_search]).endAt(['${_search}\uf8ff']);
    }

    // Convert raw Map<String,dynamic> into StockItem
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
        onSelected: (_) => setState(() {
          _category = value ?? '';
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                final items = snap.data!.docs.map((d) => d.data()).toList();
                if (items.isEmpty) {
                  return const Center(child: Text('Nie znaleziono produktów.'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        'Ilość: ${item.quantity}'
                        '${item.unit != null ? ' ${item.unit}' : ''}',
                      ),
                      trailing: widget.isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => FirebaseFirestore.instance
                                  .collection('stock_items')
                                  .doc(item.id)
                                  .delete(),
                            )
                          : null,
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
        ).push(MaterialPageRoute(builder: (_) => AddItemScreen())),
        tooltip: 'Dodaj pozycję',
        child: const Icon(Icons.add),
      ),
    );
  }
}
