// lib/screens/main_menu_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _downloadApp(BuildContext context) async {
    final url = Uri.parse('https://<YOUR-PROJECT>.web.app/app-release.apk');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd przy pobieraniu aplikacji')));
    }
  }

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
            'Strefa Ciszy – inventory',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),

          if (isAdmin) ...[
            ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Użytkowników'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => ManageUsersScreen())),
            ),
            Divider(),
          ],

          ListTile(
            leading: Icon(Icons.inventory_2),
            title: Text('Inwentaryzacja'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InventoryListScreen(isAdmin: isAdmin),
              ),
            ),
          ),

          ListTile(
            leading: Icon(Icons.person),
            title: Text('Klienci'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerListScreen(isAdmin: isAdmin),
              ),
            ),
          ),

          if (!kIsWeb)
            ListTile(
              leading: Icon(Icons.qr_code_scanner),
              title: Text('Skanuj'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => ScanScreen())),
            ),

          ListTile(
            leading: Icon(Icons.list_alt_rounded),
            title: Text('Dok. RW/MM'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => RWDocumentsScreen())),
          ),

          ListTile(
            leading: Icon(Icons.bar_chart),
            title: Text('Raporty'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ReportsScreen())),
          ),

          Divider(height: 32),

          ListTile(
            leading: Icon(Icons.download_rounded),
            title: Text('Pobierz sc_inventory'),
            subtitle: Text('Android apk'),
            onTap: () => _downloadApp(context),
          ),
        ],
      ),
    );
  }
}
