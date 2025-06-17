// lib/screens/customer_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final bool isAdmin;
  const CustomerListScreen({super.key, required this.isAdmin});

  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _col = FirebaseFirestore.instance.collection('customers');

  late final TextEditingController _searchController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _search = '';
    });
  }

  Future<void> _addCustomer() async {
    String name = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj klient'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Nazwa Klienta'),
          onChanged: (v) => name = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) {
                _col.add({
                  'name': name,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klienci'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 🔍 SEARCH FIELD
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Szukaj...',
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

      body: StreamBuilder<QuerySnapshot>(
        stream: _col.orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data!.docs;

          final filtered = _search.isEmpty
              ? docs
              : docs.where((d) {
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  return name.contains(_search.toLowerCase());
                }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('Nie znaleziono klientów.'));
          }

          return ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final snap = filtered[i];
              final d = snap.data()! as Map<String, dynamic>;
              final ts = d['createdAt'] as Timestamp?;
              final dateStr = ts != null
                  ? DateFormat(
                      'dd.MM.yyyy • HH:mm',
                      'pl_PL',
                    ).format(ts.toDate().toLocal())
                  : '';

              return ListTile(
                title: Text(d['name'] ?? '—'),
                subtitle: ts != null ? Text(dateStr) : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(
                      customerId: snap.id,
                      isAdmin: widget.isAdmin,
                    ),
                  ),
                ),
                trailing: widget.isAdmin
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _col.doc(snap.id).delete(),
                      )
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
              tooltip: 'Dodaj Klient',
              onPressed: _addCustomer,
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }
}
