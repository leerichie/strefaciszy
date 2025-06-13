// lib/screens/main_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'manage_users_screen.dart';

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
            'Witaj w Strefie Ciszy!',
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
            onTap: () {},
          ),
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
