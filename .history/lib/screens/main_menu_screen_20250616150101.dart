// lib/screens/main_menu_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/item_detail_screen.dart';
import 'package:strefa_ciszy/screens/rw_documents_screen.dart';
import 'package:strefa_ciszy/screens/reports_screen.dart';
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
        title: Text('Panel'),
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
            'Strefa Ciszy _inventory',
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
            title: Text('Inwentaryzacja'),
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

          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Konfig.(TODO)'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
