// lib/screens/main_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/item_detail_screen.dart';
<<<<<<< HEAD
=======
import 'package:strefa_ciszy/screens/rw_documents_screen.dart';
import 'package:strefa_ciszy/screens/reports_screen.dart';
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
import 'manage_users_screen.dart';
import 'scan_screen.dart';

class MainMenuScreen extends StatelessWidget {
  final String role;
  const MainMenuScreen({super.key, required this.role});

  static const String routeName = '/main-menu';

  Future<void> _signOut(BuildContext ctx) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Menu'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
<<<<<<< HEAD
            'Witaj w Strefie Ciszy!',
=======
            'Strefa Ciszy: inventory',
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),

          // Admin-only option:
          if (role == 'admin') ...[
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
            title: Text('Inwenteryzacja'),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => InventoryListScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Klienci'),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => CustomerListScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.qr_code_scanner),
            title: Text('Scan Item'),
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
<<<<<<< HEAD
=======

          ListTile(
            leading: Icon(Icons.list_alt_rounded),
            title: Text('Dok. RW/MM'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => RWDocumentsScreen()),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.list_alt_rounded),
            title: Text('Raporty'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => ReportsScreen()),
              );
            },
          ),

>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Konfig.'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
