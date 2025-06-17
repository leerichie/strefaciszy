import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  late StreamSubscription<QuerySnapshot> _catSub;
  late final TextEditingController _searchController;

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
    _searchController.dispose();
    _catSub.cancel();
    super.dispose();
  }

  void _resetSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _search = '';
    });
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
                  onPressed: _resetSearch,
                ),
              ],
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
                ..._categories.map((cat) {
                  final label = cat[0].toUpperCase() + cat.substring(1);
                  return _buildCategoryChip(cat, label);
                }),
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
                            '${d['barcode'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.isAdmin) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => FirebaseFirestore.instance
                                  .collection('stock_items')
                                  .doc(snap.id)
                                  .delete(),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(itemId: snap.id),
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
