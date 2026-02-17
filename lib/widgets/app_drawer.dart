// widgets/app_drawer.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/archives_screen.dart';
import 'package:strefa_ciszy/screens/chat_list_screen.dart';
import 'package:strefa_ciszy/screens/contact_detail_screen.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/customer_detail_screen.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/login_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/screens/project_editor_screen.dart';
import 'package:strefa_ciszy/screens/projects_list_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  static const favCustomer = 'favouriteCustomers';
  static const favProject = 'favouriteProjects';

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  static bool _magExpanded = false;
  static bool _klientExpanded = false;
  static bool _klientFavExpanded = false;
  static bool _kontaktExpanded = false;
  static bool _projectExpanded = false;
  static bool _projectFavExpanded = false;
  final _favProjectsController = ExpansibleController();
  final _favCustomersController = ExpansibleController();
  final _magController = ExpansibleController();
  final _clientsController = ExpansibleController();
  final _contactsController = ExpansibleController();
  final _projectsController = ExpansibleController();

  @override
  void initState() {
    super.initState();
    _cleanupFavorites();
  }

  void _collapseAll() {
    _favProjectsController.collapse();
    _favCustomersController.collapse();
    _magController.collapse();
    _clientsController.collapse();
    _contactsController.collapse();
    _projectsController.collapse();

    setState(() {
      _magExpanded = false;
      _klientExpanded = false;
      _klientFavExpanded = false;
      _kontaktExpanded = false;
      _projectExpanded = false;
      _projectFavExpanded = false;
    });
  }

  int _sumUnreadFromChats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) {
    int sum = 0;
    for (final d in docs) {
      final data = d.data();
      final v = data['unread_$uid'];
      if (v is int) {
        sum += v;
      } else if (v is num)
        sum += v.toInt();
    }
    return sum;
  }

  Widget _badgePill(int n) {
    if (n <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        n > 99 ? '99+' : '$n',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // remove flicker for screen change
  void _openPage(BuildContext context, Widget page) {
    if (kIsWeb) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }
  }

  Future<void> _openCustomerFromFavourite(
    BuildContext context,
    String customerId,
  ) async {
    if (!kIsWeb) {
      Navigator.of(context).pop();
    }

    final custSnap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .get();

    if (!mounted) return;

    final data = custSnap.data();
    final contactId = (data?['contactId'] as String?)?.trim();

    final Widget page;
    if (contactId != null && contactId.isNotEmpty) {
      page = ContactDetailScreen(contactId: contactId, isAdmin: true);
    } else {
      page = CustomerDetailScreen(customerId: customerId, isAdmin: true);
    }

    if (kIsWeb) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }
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

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
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

    final inner = Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // 1) scrollable menu
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // tap to collapse all submenus
                  InkWell(
                    onTap: _collapseAll,
                    child: Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/favicon/Icon-512.png'),
                          fit: BoxFit.scaleDown,
                        ),
                      ),
                    ),
                  ),

                  const Divider(color: Colors.white54),

                  ListTile(
                    leading: const Icon(Icons.home, color: Colors.white),
                    title: Text('Home', style: menuTitles),
                    onTap: () =>
                        _openPage(context, const MainMenuScreen(role: 'admin')),
                  ),

                  // — Ulubione projekt
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
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final docs = favSnap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return ExpansionTile(
                            controller: _favProjectsController,
                            leading: const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            title: Text(
                              'Oznaczone projekty',
                              style: menuTitles,
                            ),
                            childrenPadding: const EdgeInsets.only(left: 16),
                            initiallyExpanded: _projectFavExpanded,
                            onExpansionChanged: (val) {
                              setState(() => _projectFavExpanded = val);
                            },
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
                                      title: Text(title, style: menuTitles),
                                      onTap: () => _openPage(
                                        context,
                                        ProjectEditorScreen(
                                          customerId: customerId,
                                          projectId: doc.id,
                                          isAdmin: true,
                                        ),
                                      ),
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

                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection(AppDrawer.favCustomer)
                            .orderBy('name')
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final favDocs = snap.data?.docs ?? [];
                          if (favDocs.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return ExpansionTile(
                            controller: _favCustomersController,
                            leading: const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            title: Text('Oznaczeni klienci', style: menuTitles),
                            childrenPadding: const EdgeInsets.only(left: 16),
                            initiallyExpanded: _klientFavExpanded,
                            onExpansionChanged: (val) {
                              setState(() => _klientFavExpanded = val);
                            },
                            children: favDocs.map((d) {
                              final data = d.data();
                              final name = data['name'] as String? ?? '—';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const SizedBox(width: 24),
                                title: Text(name, style: menuTitles),
                                onTap: () =>
                                    _openCustomerFromFavourite(context, d.id),
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
                    ),

                  // Magazyn expansion
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
                      controller: _magController,
                      leading: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white,
                      ),
                      title: Text('Magazyn', style: menuTitles),
                      childrenPadding: const EdgeInsets.only(left: 16),
                      initiallyExpanded: _magExpanded,
                      onExpansionChanged: (val) {
                        setState(() => _magExpanded = val);
                      },
                      children: [
                        ListTile(
                          leading: const Icon(Icons.list, color: Colors.white),
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
                                builder: (_) =>
                                    const ScanScreen(purpose: ScanPurpose.add),
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

                  // — Klienci
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      unselectedWidgetColor: Colors.white70,
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.tealAccent,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.white),
                      title: Text('Klienci', style: menuTitles),
                      onTap: () => _openPage(
                        context,
                        const CustomerListScreen(isAdmin: true),
                      ),
                    ),
                  ),

                  // — Projekty
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
                      child: ListTile(
                        leading: const Icon(
                          Icons.edit_document,
                          color: Colors.white,
                        ),
                        title: Text('Projekty', style: menuTitles),
                        onTap: () => _openPage(
                          context,
                          const ProjectsListScreen(isAdmin: true),
                        ),
                      ),
                    ),

                  // — Kontakty
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      unselectedWidgetColor: Colors.white70,
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.tealAccent,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.contact_phone_outlined,
                        color: Colors.white,
                      ),
                      title: Text('Kontakty', style: menuTitles),
                      onTap: () => _openPage(
                        context,
                        const ContactsListScreen(isAdmin: true),
                      ),
                    ),
                  ),
                  Divider(),
                  // Chat
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      unselectedWidgetColor: Colors.white70,
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.tealAccent,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: uid == null
                        ? ListTile(
                            leading: const Icon(
                              Icons.chat,
                              color: Colors.white,
                            ),
                            title: Text('Chat', style: menuTitles),
                            onTap: () =>
                                _openPage(context, const ChatListScreen()),
                          )
                        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .where('members', arrayContains: uid)
                                .snapshots(),
                            builder: (ctx, snap) {
                              final docs = snap.data?.docs ?? const [];
                              final total = _sumUnreadFromChats(docs, uid);

                              return ListTile(
                                leading: const Icon(
                                  Icons.chat,
                                  color: Colors.white,
                                ),
                                title: Text('Chat', style: menuTitles),
                                trailing: _badgePill(total),
                                onTap: () =>
                                    _openPage(context, const ChatListScreen()),
                              );
                            },
                          ),
                  ),
                  Divider(),
                  // Chat
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      unselectedWidgetColor: Colors.white70,
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.tealAccent,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.archive, color: Colors.white),
                      title: Text('ARCHIVE', style: menuTitles),
                      onTap: () => _openPage(context, const ArchivesScreen()),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _signOut,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Image.asset(
                  'assets/images/dev_logo.png',
                  width: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (kIsWeb) {
      return inner;
    } else {
      return Drawer(width: 240, child: inner);
    }
  }
}
