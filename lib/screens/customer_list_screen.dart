// lib/screens/customer_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'customer_detail_screen.dart';
import 'inventory_list_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final bool isAdmin;
  const CustomerListScreen({super.key, required this.isAdmin});

  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final CollectionReference _col = FirebaseFirestore.instance.collection(
    'customers',
  );
  late final TextEditingController _searchController;
  String _search = '';

  // preload contacts
  List<String> _contactNames = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _contactDocs = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadContactNames();
  }

  Future<void> _loadContactNames() async {
    final snap = await FirebaseFirestore.instance
        .collection('contacts')
        .orderBy('name')
        .get();
    setState(() {
      _contactDocs = snap.docs;
      _contactNames = snap.docs
          .map((d) => (d.data()! as Map<String, dynamic>)['name'] as String)
          .toList();
    });
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
        title: const Text('Dodaj klienta'),
        content: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty)
              return const Iterable<String>.empty();
            return _contactNames.where(
              (option) => option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            controller.text = name;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
            controller.addListener(() {
              name = controller.text.trim();
            });
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Nazwa Klienta'),
            );
          },
          onSelected: (selection) {
            name = selection;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) {
                QueryDocumentSnapshot<Map<String, dynamic>>? contactDoc;
                for (var d in _contactDocs) {
                  if ((d.data()!['name'] as String) == name) {
                    contactDoc = d;
                    break;
                  }
                }
                final data = <String, dynamic>{
                  'name': name,
                  'createdAt': FieldValue.serverTimestamp(),
                };
                if (contactDoc != null) {
                  data['contactId'] = contactDoc.id;
                }
                _col.add(data);
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
    final isAdmin = widget.isAdmin;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Klienci'),
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
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black,
              child: IconButton(
                icon: const Icon(Icons.home),
                color: Colors.white,
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const MainMenuScreen(role: 'admin'),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
          ),
        ],
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
              final doc = filtered[i];
              final data = doc.data()! as Map<String, dynamic>;
              final ts = data['createdAt'] as Timestamp?;
              final dateStr = ts != null
                  ? DateFormat(
                      'dd.MM.yyyy • HH:mm',
                      'pl_PL',
                    ).format(ts.toDate().toLocal())
                  : '';

              return ListTile(
                title: Text(data['name'] ?? '—'),
                subtitle: ts != null ? Text(dateStr) : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(
                      customerId: doc.id,
                      isAdmin: isAdmin,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<QuerySnapshot>(
                      future: _col.doc(doc.id).collection('projects').get(),
                      builder: (ctx2, snap2) {
                        if (snap2.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        final count = snap2.data?.docs.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'P: $count',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Usuń klienta',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Usuń klienta?'),
                              content: Text(
                                'Na pewno usunąć klienta "${data['name']}" i wszystkie projekty?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Anuluj'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Usuń'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await _col.doc(doc.id).delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Klient "${data['name']}" usunięty',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Dodaj Klienta',
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add),
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
                  tooltip: 'Kontakty',
                  icon: const Icon(Icons.contact_mail_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ContactsListScreen()),
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
