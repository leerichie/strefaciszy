// lib/screens/main_menu_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:strefa_ciszy/screens/audit_log_screen.dart';
import 'customer_list_screen.dart';
import 'inventory_list_screen.dart';
import 'scan_screen.dart';
import 'manage_users_screen.dart';

class MainMenuScreen extends StatelessWidget {
  final String role;
  const MainMenuScreen({super.key, required this.role});

  Future<void> _signOut(BuildContext ctx) async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _downloadApp(BuildContext context) async {
    final url = Uri.parse('https://strefa-ciszy.web.app/app-release.apk');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Błąd przy pobieraniu aplikacji')),
      );
    }
  }

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

      // —— your existing menu items ——
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
            leading: const Icon(Icons.person),
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

          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('download apk (Android)'),
            subtitle: const Text('Android'),
            onTap: () => _downloadApp(context),
          ),
        ],
      ),

      // —— Scan FAB always visible and center‐docked over the bar ——
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

      // —— Persistent bottom bar with Inventory & Clients shortcuts ——
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Inventory shortcut
                IconButton(
                  tooltip: 'Inwentaryzacja',
                  icon: const Icon(Icons.inventory_2),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InventoryListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),

                // Clients shortcut
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.person),
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
