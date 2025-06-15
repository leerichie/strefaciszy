// lib/screens/inventory_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/screens/add_item_screen.dart';
import 'item_detail_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  _InventoryListScreenState createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  String _search = '';
  String _category = '';

  Query get _query {
    var q = FirebaseFirestore.instance
        .collection('stock_items')
        .orderBy('name');

    if (_category.isNotEmpty) {
      q = q.where('category', isEqualTo: _category);
    }

    if (_search.isNotEmpty) {
      final end =
          _search.substring(0, _search.length - 1) +
          String.fromCharCode(_search.codeUnitAt(_search.length - 1) + 1);
      q = q
          .where('name', isGreaterThanOrEqualTo: _search)
          .where('name', isLessThan: end);
    }

    return q;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
        ),
      ),

      // category filter row
      body: Column(
        children: [
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryChip(null, 'All'),
                _buildCategoryChip('cables', 'Cables'),
                _buildCategoryChip('projectors', 'Projectors'),
                _buildCategoryChip('speakers', 'Speakers'),
                _buildCategoryChip('sweets', 'Sweets'),
                // add more categories as needed
              ],
            ),
          ),
          SizedBox(height: 8),

          // the actual list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _query.snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text('No items found.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data()! as Map<String, dynamic>;
                    return ListTile(
                      title: Text(d['name'] ?? '—'),
                      subtitle: Text(
                        'Qty: ${d['quantity']}\nCategory: ${d['category']}',
                      ),
                      isThreeLine: true,
                      trailing: Text(d['barcode'] ?? ''),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ItemDetailScreen(code: d['barcode'] ?? ''),
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

      // add new item fab for admins
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => AddItemScreen()));
        },
        tooltip: 'Add Inventory Item',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label) {
    final selected = (value ?? '') == _category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _category = value ?? '';
          });
        },
      ),
    );
  }
}
