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

  // Future<void> patchMissingUnitsInRWDocuments() async {
  //   final rwDocs = await FirebaseFirestore.instance
  //       .collection('rw_documents')
  //       .get();
  //   int updated = 0;
  //   int skipped = 0;

  //   for (final doc in rwDocs.docs) {
  //     final items = List<Map<String, dynamic>>.from(doc['items'] ?? []);
  //     bool changed = false;

  //     for (final item in items) {
  //       if (item['unit'] == null || item['unit'].toString().isEmpty) {
  //         final itemId = item['itemId'];
  //         if (itemId != null) {
  //           final stockSnap = await FirebaseFirestore.instance
  //               .collection('stock_items')
  //               .doc(itemId)
  //               .get();
  //           if (stockSnap.exists) {
  //             final stockUnit = stockSnap.data()?['unit'];
  //             if (stockUnit != null) {
  //               item['unit'] = stockUnit;
  //               changed = true;
  //             }
  //           }
  //         }
  //       }
  //     }

  //     if (changed) {
  //       await FirebaseFirestore.instance
  //           .collection('rw_documents')
  //           .doc(doc.id)
  //           .update({'items': items});
  //       updated++;
  //     } else {
  //       skipped++;
  //     }
  //   }

  //   print('✅ Patched: $updated');
  //   print('⏭️ Skipped (no change needed): $skipped');
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
              onTap: () async {
                final code = await Navigator.of(
                  context,
                ).push<String>(MaterialPageRoute(builder: (_) => ScanScreen()));
                if (code != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ItemDetailScreen(code: code),
                    ),
                  );
                }
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

          // ElevatedButton(
          //   child: Text("Patch missing jm"),
          //   onPressed: () async {
          //     await patchMissingUnitsInRWDocuments();
          //     ScaffoldMessenger.of(
          //       context,
          //     ).showSnackBar(SnackBar(content: Text('Finished patching.')));
          //   },
          // ),
        ],
      ),
    );
  }
}
