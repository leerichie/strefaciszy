// lib/screens/main_menu_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:strefa_ciszy/data/test_categories.dart';
import 'package:strefa_ciszy/data/test_stock_items.dart';
import 'package:strefa_ciszy/screens/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:strefa_ciszy/screens/audit_log_screen.dart';
import 'customer_list_screen.dart';
import 'inventory_list_screen.dart';
import 'scan_screen.dart';
import 'manage_users_screen.dart';

class MainMenuScreen extends StatefulWidget {
  final String role;
  const MainMenuScreen({Key? key, required this.role}) : super(key: key);

  @override
  _MainMenuScreenState createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  String get role => widget.role;

  Future<void> _signOut(BuildContext ctx) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _downloadApp(BuildContext context) async {
    final url = Uri.parse('https://strefa-ciszy.web.app/app-release.apk');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Błąd pobieranie apka')));
    }
  }

  // Future<void> _removeHomeTheatre(BuildContext context) async {
  //   final batch = FirebaseFirestore.instance.batch();
  //   final catCol = FirebaseFirestore.instance.collection('categories');
  //   for (final snap
  //       in await catCol
  //           .where('name', isEqualTo: 'Home Theatre')
  //           .get()
  //           .then((s) => s.docs)) {
  //     batch.delete(snap.reference);
  //   }
  //   for (final snap
  //       in await catCol
  //           .where('name', isEqualTo: 'Home Theater')
  //           .get()
  //           .then((s) => s.docs)) {
  //     batch.delete(snap.reference);
  //   }
  //   final itemsCol = FirebaseFirestore.instance.collection('stock_items');
  //   final itemsSnap = await itemsCol
  //       .where('category', whereIn: ['Home Theatre', 'Home Theater'])
  //       .get();
  //   for (final doc in itemsSnap.docs) {
  //     batch.update(doc.reference, {'category': 'Wzmacniacz'});
  //   }
  //   await batch.commit();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('✅ Removed all Home Theatre categories')),
  //   );
  // }

  // Future<void> _addTestCategories(BuildContext context) async {
  //   final batch = FirebaseFirestore.instance.batch();
  //   final catCol = FirebaseFirestore.instance.collection('categories');
  //   for (final name in newCategories) {
  //     final exists = await catCol.where('name', isEqualTo: name).limit(1).get();
  //     if (exists.docs.isEmpty) {
  //       batch.set(catCol.doc(), {'name': name});
  //     }
  //   }
  //   final itemsCol = FirebaseFirestore.instance.collection('stock_items');
  //   final homeSnap = await itemsCol
  //       .where('category', isEqualTo: 'Home Theatre')
  //       .get();
  //   for (final doc in homeSnap.docs) {
  //     batch.update(doc.reference, {'category': 'Wzmacniacz'});
  //   }
  //   await batch.commit();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text('✅ Added categories & migrated Home Theatre items'),
  //     ),
  //   );
  // }

  // Future<void> _addTestItems() async {
  //   final batch = FirebaseFirestore.instance.batch();
  //   final col = FirebaseFirestore.instance.collection('stock_items');
  //   for (final item in testStockItems) {
  //     batch.set(col.doc(), item);
  //   }
  //   await batch.commit();
  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(const SnackBar(content: Text('✅ Added 50 test items')));
  // }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Strefa Ciszy _inventory',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Użytkowników'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
              ),
            ),
            const Divider(),
          ],

          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Inwentaryzacja'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InventoryListScreen(isAdmin: isAdmin),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Klienci'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerListScreen(isAdmin: isAdmin),
              ),
            ),
          ),

          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Skanuj'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
            ),

          const Divider(),

          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: const Text('Historia RW'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AuditLogScreen())),
            ),

          const Divider(),

          // ListTile(
          //   leading: const Icon(Icons.category),
          //   title: const Text('Remove all Home Theatre categories'),
          //   onTap: () => _removeHomeTheatre(context),
          // ),
          // const Divider(),

          // ListTile(
          //   leading: const Icon(Icons.category),
          //   title: const Text('Add new categories & migrate'),
          //   onTap: () => _addTestCategories(context),
          // ),
          // const Divider(),

          // ListTile(
          //   leading: const Icon(Icons.build),
          //   title: const Text('Dummy 50 stock items'),
          //   onTap: _addTestItems,
          // ),
          // const Divider(),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('download apk (Android)'),
            subtitle: const Text('Android'),
            onTap: () => _downloadApp(context),
            trailing: SizedBox(
              width: 80,
              height: 80,
              child: FittedBox(
                fit: BoxFit.contain,
                child: QrImageView(
                  data: 'https://strefa-ciszy.web.app/app-release.apk',
                  version: QrVersions.auto,
                  size: 150,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !kIsWeb
          ? FloatingActionButton(
              tooltip: 'Skanuj',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: const Icon(Icons.qr_code_scanner, size: 32),
            )
          : null,
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
                  tooltip: 'Inwentaryzacja',
                  icon: const Icon(Icons.inventory_2),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InventoryListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.group),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
