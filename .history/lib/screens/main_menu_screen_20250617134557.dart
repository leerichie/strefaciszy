// lib/screens/main_menu_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_list_screen.dart';
import 'inventory_list_screen.dart';
import 'item_detail_screen.dart';
import 'rw_documents_screen.dart';
import 'reports_screen.dart';
import 'manage_users_screen.dart';
import 'scan_screen.dart';

class MainMenuScreen extends StatelessWidget {
  final String role;
  const MainMenuScreen({super.key, required this.role});

  Future<void> _signOut(BuildContext ctx) async {
    await FirebaseAuth.instance.signOut();
  }

  // Future<void> _patchAddProducerField() async {
  //   final batch = FirebaseFirestore.instance.batch();
  //   final itemsSnap = await FirebaseFirestore.instance
  //       .collection('stock_items')
  //       .get();

  //   for (final doc in itemsSnap.docs) {
  //     final data = doc.data();
  //     if (!data.containsKey('producent')) {
  //       batch.update(
  //         FirebaseFirestore.instance.collection('stock_items').doc(doc.id),
  //         {'producent': ''},
  //       );
  //     }
  //   }

  //   await batch.commit();
  // }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            'Strefa Ciszy _inventory',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),

          if (isAdmin) ...[
            ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Użytkowników'),
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => ManageUsersScreen()));
              },
            ),
            Divider(),
          ],

          ListTile(
            leading: Icon(Icons.inventory_2),
            title: Text('Inwentaryzacja'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InventoryListScreen(isAdmin: isAdmin),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.person),
            title: Text('Klienci'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CustomerListScreen(isAdmin: isAdmin),
                ),
              );
            },
          ),

          if (!kIsWeb)
            ListTile(
              leading: Icon(Icons.qr_code_scanner),
              title: Text('Skanuj'),
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => ScanScreen()));
              },
            ),

          ListTile(
            leading: Icon(Icons.list_alt_rounded),
            title: Text('Dok. RW/MM'),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => RWDocumentsScreen()));
            },
          ),

          ListTile(
            leading: Icon(Icons.list_alt_rounded),
            title: Text('Raporty'),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => ReportsScreen()));
            },
          ),

          // if (isAdmin)
          //   Padding(
          //     padding: const EdgeInsets.only(top: 32),
          //     child: ElevatedButton(
          //       child: const Text('Patch: add producent field'),
          //       onPressed: () async {
          //         await _patchAddProducerField();
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           const SnackBar(
          //             content: Text('Finished patching producent field.'),
          //           ),
          //         );
          //       },
          //     ),
          //   ),
        ],
      ),
    );
  }
}
