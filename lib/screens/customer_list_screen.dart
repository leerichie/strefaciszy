// lib/screens/customer_list_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/screens/add_contact_screen.dart';
import 'package:strefa_ciszy/screens/contact_detail_screen.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'customer_detail_screen.dart';

enum SortMode { nameAZ, nameZA, newest, oldest }

SortMode _sortMode = SortMode.newest;

class CustomerListScreen extends StatefulWidget {
  final bool isAdmin;
  final bool showAddOnOpen;
  const CustomerListScreen({
    super.key,
    required this.isAdmin,
    this.showAddOnOpen = false,
  });

  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final CollectionReference _col = FirebaseFirestore.instance.collection(
    'customers',
  );
  late final TextEditingController _searchController;
  String _search = '';

  List<String> _contactNames = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _contactDocs = [];
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _contactsSub;
  Set<String> _favCustomerIds = {};
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _favsCustSub;
  late SortMode _sortMode;
  bool _sortLoaded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _contactsSub = FirebaseFirestore.instance
        .collection('contacts')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          setState(() {
            _contactDocs = snap.docs;
            _contactNames = snap.docs
                .map((d) => (d.data())['name'] as String)
                .toList();
          });
        });
    _sortMode = SortMode.newest;
    _loadSortMode();
    if (widget.showAddOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addCustomer();
      });
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _favsCustSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favouriteCustomers')
        .snapshots()
        .listen((snap) {
          setState(() {
            _favCustomerIds = snap.docs.map((d) => d.id).toSet();
          });
        });
  }

  Future<void> _loadSortMode() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final val = (doc.data()?['customerSortMode'] as String?) ?? 'newest';
    final found = SortMode.values.firstWhere(
      (m) => m.name == val,
      orElse: () => SortMode.newest,
    );
    setState(() {
      _sortMode = found;
      _sortLoaded = true;
    });
  }

  Future<void> _saveSortMode(SortMode m) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _sortMode = m);
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'customerSortMode': m.name,
    }, SetOptions(merge: true));
  }

  Future<void> _loadContactNames() async {
    final snap = await FirebaseFirestore.instance
        .collection('contacts')
        .orderBy('name')
        .get();
    setState(() {
      _contactDocs = snap.docs;
      _contactNames = snap.docs
          .map((d) => (d.data())['name'] as String)
          .toList();
    });
  }

  Future<void> _editCustomers() async {
    final snap = await _col.orderBy('createdAt').get();
    final docs = snap.docs;

    final edits = {
      for (var d in docs)
        d.id: ((d.data() as Map<String, dynamic>)['name'] as String),
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edytuj klient'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: StatefulBuilder(
            builder: (ctx2, setState) {
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final id = doc.id;
                  return TextFormField(
                    initialValue: edits[id],
                    decoration: InputDecoration(labelText: 'Klient:'),
                    onChanged: (v) => setState(() => edits[id] = v.trim()),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final oldName = data['name'] as String;
                final newName = edits[doc.id]!;
                if (newName.isNotEmpty && newName != oldName) {
                  await _col.doc(doc.id).update({'name': newName});
                  final contactId = data['contactId'] as String?;
                  if (contactId != null) {
                    try {
                      debugPrint('updating contact $contactId → $newName');
                      await FirebaseFirestore.instance
                          .collection('contacts')
                          .doc(contactId)
                          .update({'name': newName});
                    } catch (e) {
                      debugPrint('failed to update contact $contactId: $e');
                    }
                  }
                }
              }
              await _loadContactNames();

              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavouriteCustomer(String customerId, String name) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favouriteCustomers')
        .doc(customerId);

    if (_favCustomerIds.contains(customerId)) {
      await ref.delete();
    } else {
      await ref.set({'name': name});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _contactsSub.cancel();
    _favsCustSub.cancel();
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
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) =>
            AddContactScreen(isAdmin: widget.isAdmin, linkedCustomerId: null),
      ),
    );

    if (!mounted || result == null) return;

    var name = (result['name'] ?? '').toString().trim();
    final contactId = result['contactId'] as String?;
    if (contactId == null) return;

    if (name.isEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('contacts')
          .doc(contactId)
          .get();
      name = (snap.data()?['name'] ?? '').toString().trim();
    }
    if (name.isEmpty) return;

    final custRef = await _col.add({
      'name': name,
      'nameFold': name.toLowerCase(),
      'contactId': contactId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('contacts').doc(contactId).set({
      'linkedCustomerId': custRef.id,
    }, SetOptions(merge: true));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          customerId: custRef.id,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.isAdmin;
    final title = 'Lista Klientów';
    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Dodaj Klienta',
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      centreTitle: true,
      title: title,
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
              PopupMenuButton<SortMode>(
                icon: const Icon(Icons.sort),
                onSelected: _saveSortMode,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: SortMode.nameAZ, child: Text('A → Z')),
                  PopupMenuItem(value: SortMode.nameZA, child: Text('Z → A')),
                  PopupMenuItem(
                    value: SortMode.newest,
                    child: Text('Najnowszy'),
                  ),
                  PopupMenuItem(
                    value: SortMode.oldest,
                    child: Text('Najstarszy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // actions: [
      //   Padding(
      //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
      //     child: CircleAvatar(
      //       backgroundColor: Colors.black,
      //       child: IconButton(
      //         icon: const Icon(Icons.home),
      //         color: Colors.white,
      //         tooltip: 'Home',
      //         onPressed: () {
      //           Navigator.of(context).pushAndRemoveUntil(
      //             MaterialPageRoute(
      //               builder: (_) => const MainMenuScreen(role: 'admin'),
      //             ),
      //             (route) => false,
      //           );
      //         },
      //       ),
      //     ),
      //   ),
      // ],
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
              ? docs.toList()
              : docs.where((d) {
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  return name.contains(_search.toLowerCase());
                }).toList();

          int cmpName(Map<String, dynamic> a, Map<String, dynamic> b) =>
              (a['name'] ?? '').toString().toLowerCase().compareTo(
                (b['name'] ?? '').toString().toLowerCase(),
              );

          int cmpDate(Map<String, dynamic> a, Map<String, dynamic> b) {
            final ta =
                (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final tb =
                (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return ta.compareTo(tb);
          }

          switch (_sortMode) {
            case SortMode.nameAZ:
              filtered.sort(
                (x, y) => cmpName(
                  x.data()! as Map<String, dynamic>,
                  y.data()! as Map<String, dynamic>,
                ),
              );
              break;
            case SortMode.nameZA:
              filtered.sort(
                (x, y) => cmpName(
                  y.data()! as Map<String, dynamic>,
                  x.data()! as Map<String, dynamic>,
                ),
              );
              break;
            case SortMode.oldest:
              filtered.sort(
                (x, y) => cmpDate(
                  x.data()! as Map<String, dynamic>,
                  y.data()! as Map<String, dynamic>,
                ),
              );
              break;
            case SortMode.newest:
              filtered.sort(
                (x, y) => cmpDate(
                  y.data()! as Map<String, dynamic>,
                  x.data()! as Map<String, dynamic>,
                ),
              );
              break;
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
                // onTap: () => Navigator.of(context).push(
                //   MaterialPageRoute(
                //     builder: (_) => CustomerDetailScreen(
                //       customerId: doc.id,
                //       isAdmin: isAdmin,
                //     ),
                //   ),
                // ),
                onTap: () {
                  final contactId = data['contactId'] as String?;
                  if (contactId == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ContactDetailScreen(
                        contactId: contactId,
                        isAdmin: isAdmin,
                      ),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _favCustomerIds.contains(doc.id)
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                      ),
                      tooltip: _favCustomerIds.contains(doc.id)
                          ? 'Usuń z ulubionych'
                          : 'Dodaj do ulubionych',
                      onPressed: () =>
                          _toggleFavouriteCustomer(doc.id, data['name'] ?? ''),
                    ),
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
                                'Na pewno usunąć klienta "${data['name']}" i związany projekty?',
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
      // floatingActionButton: FloatingActionButton(
      //   tooltip: 'Dodaj Klienta',
      //   onPressed: _addCustomer,
      //   child: const Icon(Icons.person_add),
      // ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // bottomNavigationBar: SafeArea(
      //   child: BottomAppBar(
      //     shape: const CircularNotchedRectangle(),
      //     notchMargin: 6,
      //     child: Padding(
      //       padding: const EdgeInsets.symmetric(horizontal: 32),
      //       child: Row(
      //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //         children: [
      //           IconButton(
      //             tooltip: 'Kontakty',
      //             icon: const Icon(Icons.contact_mail_outlined),
      //             onPressed: () => Navigator.of(context).push(
      //               MaterialPageRoute(builder: (_) => ContactsListScreen()),
      //             ),
      //           ),

      //           // IconButton(
      //           //   tooltip: 'Edytuj klientów',
      //           //   icon: const Icon(Icons.edit),
      //           //   onPressed: _editCustomers,
      //           // ),
      //           IconButton(
      //             tooltip: 'Skanuj',
      //             icon: const Icon(Icons.qr_code_scanner),
      //             onPressed: () => Navigator.of(
      //               context,
      //             ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
      //           ),
      //         ],
      //       ),
      //     ),
      //   ),
      // ),
    );
  }
}
