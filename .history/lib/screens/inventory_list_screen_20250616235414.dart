import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/screens/add_item_screen.dart';
import 'package:strefa_ciszy/screens/item_detail_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

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
  late StreamSubscription<QuerySnapshot> _catSub;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Query get _query {
    var q = FirebaseFirestore.instance
        .collection('stock_items')
        .orderBy('name');
    if (_category.isNotEmpty) {
      q = q.where('category', isEqualTo: _category);
    }
    return q;
  }

  Widget _buildCategoryChip(String? value, String label) {
    final selected = (value ?? '') == _category;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = value ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inwentaryzacja'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Szukaj po nazwie…',
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
      body: Column(
        children: [
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryChip(null, 'Wszystko'),
                ..._categories.map(
                  (cat) => _buildCategoryChip(
                    cat,
                    cat[0].toUpperCase() + cat.substring(1),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
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
                final filtered = _search.isEmpty
                    ? docs
                    : docs.where((d) {
                        final name = (d['name'] as String).toLowerCase();
                        return name.contains(_search.toLowerCase());
                      }).toList();
                if (filtered.isEmpty) {
                  return Center(child: Text('Nie znaleziono produktów.'));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final snap = filtered[i];
                    final d = snap.data()! as Map<String, dynamic>;
                    return ListTile(
                      title: Text(d['name'] ?? '—'),
                      subtitle: Text(
                        'Ilość: ${d['quantity']}\nKategoria: ${d['category']}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${d['barcode'] ?? ""}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.isAdmin) ...[
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('stock_items')
                                    .doc(snap.id)
                                    .delete();
                              },
                            ),
                          ],
                        ],
                      ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => AddItemScreen())),
        tooltip: 'Dodaj do inwentaryzacji',
        child: Icon(Icons.add),
      ),
    );
  }
}
