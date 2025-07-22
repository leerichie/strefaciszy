import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/add_contact_screen.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/login_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/screens/project_editor_screen.dart';
import 'package:strefa_ciszy/screens/rw_documents_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

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

              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  unselectedWidgetColor: Colors.white70,
                  colorScheme: ColorScheme.dark(
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
                            builder: (_) => const CustomerListScreen(
                              isAdmin: true,
                              showAddOnOpen: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
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
                  title: Text('Inwentaryzacja', style: menuTitles),

                  childrenPadding: const EdgeInsets.only(left: 16),
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
                          MaterialPageRoute(builder: (_) => const ScanScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Kontakty
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
                      leading: const Icon(Icons.people, color: Colors.white),
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
                            builder: (_) => const AddContactScreen(),
                          ),
                        );
                      },
                    ),
                  ],
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
                        .collection('favourites')
                        .snapshots(),
                    builder: (ctx, favSnap) {
                      if (favSnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final docs = favSnap.data?.docs ?? [];

                      return ExpansionTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text('Ulubiony', style: menuTitles),
                        childrenPadding: const EdgeInsets.only(left: 16),
                        children: docs.isEmpty
                            ? [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const SizedBox(width: 24),
                                  title: Text('- Brak', style: menuTitles),
                                ),
                              ]
                            : docs.map((doc) {
                                final data = doc.data();
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const SizedBox(width: 24),
                                  title: Text(
                                    data['title'] as String? ?? '–',
                                    style: menuTitles,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProjectEditorScreen(
                                          customerId:
                                              data['customerId'] as String,
                                          projectId: doc.id,
                                          isAdmin: true,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
