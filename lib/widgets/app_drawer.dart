import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/add_contact_screen.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/customer_detail_screen.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/screens/project_editor_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  static const favCustomer = 'favouriteCustomers';
  static const favProject = 'favouriteProjects';

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  void initState() {
    super.initState();
    _cleanupFavorites();
  }

  Future<void> _cleanupFavorites() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      final favCustSnapshot = await userRef
          .collection(AppDrawer.favCustomer)
          .get();
      for (var doc in favCustSnapshot.docs) {
        final exists =
            (await FirebaseFirestore.instance
                    .collection('customers')
                    .doc(doc.id)
                    .get())
                .exists;
        if (!exists) await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Failed cleaning favourite customers: $e');
    }

    try {
      final favProjSnapshot = await userRef
          .collection(AppDrawer.favProject)
          .get();
      for (var doc in favProjSnapshot.docs) {
        final data = doc.data();
        final customerId = data['customerId'] as String?;
        bool exists = false;
        if (customerId != null && customerId.isNotEmpty) {
          final projectDoc = await FirebaseFirestore.instance
              .collection('customers')
              .doc(customerId)
              .collection('projects')
              .doc(doc.id)
              .get();
          exists = projectDoc.exists;
        }
        if (!exists) await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Failed cleaning favourite projects: $e');
    }
  }

  Future<void> _removeFavourite(
    BuildContext context, {
    required String uid,
    required String collection,
    required String docId,
    required String name,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuń z ulubionych?'),
        content: Text(name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(collection)
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final TextStyle menuTitles = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    return Drawer(
      width: 240,
      child: Container(
        color: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              // 1) scrollable menu
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/favicon/Icon-512.png'),
                          fit: BoxFit.scaleDown,
                        ),
                      ),
                    ),

                    const Divider(color: Colors.white54),

                    ListTile(
                      leading: const Icon(Icons.home, color: Colors.white),
                      title: Text('Home', style: menuTitles),
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const MainMenuScreen(role: 'admin'),
                          ),
                        );
                      },
                    ),

                    // — Magazyn expansion
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        unselectedWidgetColor: Colors.white70,
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.tealAccent,
                          onSurface: Colors.white,
                        ),
                      ),
                      child: ExpansionTile(
                        leading: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.white,
                        ),
                        title: Text('Magazyn', style: menuTitles),
                        childrenPadding: const EdgeInsets.only(left: 16),
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.list,
                              color: Colors.white,
                            ),
                            title: Text('List produktów', style: menuTitles),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const InventoryListScreen(isAdmin: true),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                            ),
                            title: Text('Dodać produkt', style: menuTitles),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ScanScreen(
                                    purpose: ScanPurpose.add,
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                            ),
                            title: Text('Wyszukaj produkt', style: menuTitles),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ScanScreen(
                                    purpose: ScanPurpose.search,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // — Klienci expansion
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        unselectedWidgetColor: Colors.white70,
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.tealAccent,
                          onSurface: Colors.white,
                        ),
                      ),
                      child: ExpansionTile(
                        leading: const Icon(
                          Icons.person_2_outlined,
                          color: Colors.white,
                        ),
                        title: Text('Klienci', style: menuTitles),
                        childrenPadding: const EdgeInsets.only(left: 16),
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.my_library_books_rounded,
                              color: Colors.white,
                            ),
                            title: Text('List klientów', style: menuTitles),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CustomerListScreen(isAdmin: true),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                            ),
                            title: Text('Dodaj klient', style: menuTitles),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AddContactScreen(isAdmin: true),
                                ),
                              );
                            },
                          ),

                          if (uid != null)
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection(AppDrawer.favCustomer)
                                  .orderBy('name')
                                  .snapshots(),
                              builder: (ctx, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final favDocs = snap.data?.docs ?? [];
                                if (favDocs.isEmpty)
                                  return const SizedBox.shrink();

                                return ExpansionTile(
                                  leading: const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                  ),
                                  title: Text(
                                    'Ulubione klienci',
                                    style: menuTitles,
                                  ),
                                  childrenPadding: const EdgeInsets.only(
                                    left: 16,
                                  ),
                                  children: favDocs.map((d) {
                                    final name =
                                        d.data()['name'] as String? ?? '—';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const SizedBox(width: 24),
                                      title: Text(name, style: menuTitles),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CustomerDetailScreen(
                                                  customerId: d.id,
                                                  isAdmin: true,
                                                ),
                                          ),
                                        );
                                      },
                                      onLongPress: () => _removeFavourite(
                                        context,
                                        uid: uid,
                                        collection: AppDrawer.favCustomer,
                                        docId: d.id,
                                        name: name,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    // — Kontakty expansion
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        unselectedWidgetColor: Colors.white70,
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.tealAccent,
                          onSurface: Colors.white,
                        ),
                      ),
                      child: ExpansionTile(
                        leading: const Icon(
                          Icons.contact_phone_outlined,
                          color: Colors.white,
                        ),
                        title: Text('Kontakty', style: menuTitles),
                        childrenPadding: const EdgeInsets.only(left: 16),
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.people,
                              color: Colors.white,
                            ),
                            title: Text('List kontaktów', style: menuTitles),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ContactsListScreen(isAdmin: true),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.person_add_alt,
                              color: Colors.white,
                            ),
                            title: Text('Dodaj kontakt', style: menuTitles),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AddContactScreen(
                                    isAdmin: true,
                                    forceAsContact: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // — Ulubione projekty
                    if (uid != null)
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          unselectedWidgetColor: Colors.white70,
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.tealAccent,
                            onSurface: Colors.white,
                          ),
                        ),
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection(AppDrawer.favProject)
                                  .orderBy('title')
                                  .snapshots(),
                              builder: (ctx, favSnap) {
                                if (favSnap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final docs = favSnap.data?.docs ?? [];
                                if (docs.isEmpty)
                                  return const SizedBox.shrink();

                                return ExpansionTile(
                                  leading: const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                  ),
                                  title: Text(
                                    'Ulubione projekty',
                                    style: menuTitles,
                                  ),
                                  childrenPadding: const EdgeInsets.only(
                                    left: 16,
                                  ),
                                  children: docs.isEmpty
                                      ? [
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const SizedBox(width: 24),
                                            title: Text(
                                              '– Brak –',
                                              style: menuTitles,
                                            ),
                                          ),
                                        ]
                                      : docs.map((doc) {
                                          final data = doc.data();
                                          final title =
                                              data['title'] as String? ?? '–';
                                          final customerId =
                                              data['customerId'] as String;
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const SizedBox(width: 24),
                                            title: Text(
                                              title,
                                              style: menuTitles,
                                            ),
                                            onTap: () {
                                              Navigator.of(context).pop();
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ProjectEditorScreen(
                                                        customerId: customerId,
                                                        projectId: doc.id,
                                                        isAdmin: true,
                                                      ),
                                                ),
                                              );
                                            },
                                            onLongPress: () => _removeFavourite(
                                              context,
                                              uid: uid,
                                              collection: AppDrawer.favCustomer,
                                              docId: doc.id,
                                              name: title,
                                            ),
                                          );
                                        }).toList(),
                                );
                              },
                            ),
                      ),
                  ],
                ),
              ),
              // 2) footer signature
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 16),
                child: Align(
                  alignment: Alignment.bottomRight,
                  // child: Image.asset(
                  //   'assets/images/Lee_logo_app_dev.png',
                  //   width: 80,
                  //   fit: BoxFit.contain,
                  // ),
                  child: Text(
                    'developed by LEE',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
