// lib/screens/contacts_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/add_contact_screen.dart';
import 'package:strefa_ciszy/screens/contact_detail_screen.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

class ContactsListScreen extends StatefulWidget {
  final bool isAdmin;
  final String? customerId;
  const ContactsListScreen({super.key, this.isAdmin = false, this.customerId});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  String _search = '';
  List<String> _categories = ['Wszyscy'];
  String _category = 'Wszyscy';

  late final TextEditingController _searchController;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController = TextEditingController();
    _updateStream();
  }

  Future<void> _loadCategories() async {
    final snap = await FirebaseFirestore.instance
        .collection('metadata')
        .doc('contactTypes')
        .get();
    final types = List<String>.from((snap.data()!['types'] as List));
    setState(() {
      _categories = ['Wszyscy', ...types];
    });
  }

  void _updateStream() {
    Query<Map<String, dynamic>> ref = FirebaseFirestore.instance.collection(
      'contacts',
    );
    if (_category.isNotEmpty && _category != 'Wszyscy') {
      ref = ref.where('contactType', isEqualTo: _category);
    }
    _stream = ref.orderBy('name').snapshots().handleError((e) {
      print('Firestore error: $e');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addContact() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddContactScreen(
          isAdmin: widget.isAdmin,
          linkedCustomerId: widget.customerId,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final selected = _category == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _category = selected ? '' : label;
          _updateStream();
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget dynamicTitleWidget = widget.customerId == null
        ? const Text('Kontakty', style: TextStyle(fontSize: 16))
        : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('customers')
                .doc(widget.customerId!)
                .get(),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done ||
                  !snap.hasData ||
                  snap.data!.data() == null) {
                return const Text('Kontakty');
              }
              final clientName = snap.data!.data()!['name'] as String? ?? '';
              return Text(
                'Kontakty: $clientName',
                style: TextStyle(fontSize: 16),
              );
            },
          );

    return AppScaffold(
      title: 'Kontakty',
      titleWidget: dynamicTitleWidget,
      centreTitle: true,

      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const MainMenuScreen(role: 'admin'),
                  ),
                  (route) => false,
                );
              },
              color: Colors.white,
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Szukaj…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Typ kontaktu',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              value: _category == 'Wszyscy' ? null : _category,
              items: _categories.map((cat) {
                return DropdownMenuItem(
                  value: cat == 'Wszyscy' ? '' : cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (v) => setState(() {
                _category = (v == null || v.isEmpty) ? 'Wszyscy' : v;
                _updateStream();
              }),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: (() {
                Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
                    .collection('contacts');
                if (_category != 'Wszyscy') {
                  ref = ref.where('contactType', isEqualTo: _category);
                }
                if (widget.customerId != null) {
                  ref = ref.where(
                    'linkedCustomerId',
                    isEqualTo: widget.customerId,
                  );
                }
                return ref.orderBy('name').snapshots();
              })(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data!.docs.where((doc) {
                  final name =
                      doc.data()['name']?.toString().toLowerCase() ?? '';
                  return name.contains(_search.toLowerCase());
                }).toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('Brak kontaktów.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    return ListTile(
                      title: Text(data['name'] ?? ''),
                      subtitle: Text(
                        '${data['contactType'] ?? ''} • ${data['phone'] ?? ''}',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ContactDetailScreen(
                            contactId: docs[i].id,
                            isAdmin: widget.isAdmin,
                          ),
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
        tooltip: 'Dodaj Kontakt',
        onPressed: _addContact,
        child: const Icon(Icons.person_add_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.people),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomerListScreen(isAdmin: widget.isAdmin),
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
