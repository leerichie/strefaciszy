import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/login_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

import 'customer_list_screen.dart';
import 'inventory_list_screen.dart';
import 'scan_screen.dart';
import 'manage_users_screen.dart';

class MainMenuScreen extends StatefulWidget {
  final String role;
  const MainMenuScreen({super.key, required this.role});

  @override
  _MainMenuScreenState createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  String get role => widget.role;
  bool get isAdmin => role == 'admin';

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _downloadApp(BuildContext context) async {
    final url = Uri.parse('https://strefa-ciszy.web.app/app-release.apk');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Błąd pobieranie apka')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // const Text(
        //   'Strefa Ciszy _inventory',
        //   style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        //   textAlign: TextAlign.center,
        // ),
        Image.asset('assets/images/strefa_ciszy_logo.png', width: 200),

        const SizedBox(height: 24),

        if (isAdmin) ...[
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Użytkownicy'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
            ),
          ),
          const Divider(),
        ],

        ListTile(
          leading: const Icon(Icons.inventory_2),
          title: const Text('Magazyn'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InventoryListScreen(isAdmin: isAdmin),
              ),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.people_alt_outlined),
          title: const Text('Klienci'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerListScreen(isAdmin: isAdmin),
              ),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.contact_phone_outlined),
          title: const Text('Kontakty'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ContactsListScreen(isAdmin: isAdmin),
              ),
            );
          },
        ),

        if (!kIsWeb)
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Skanuj'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ScanScreen(purpose: ScanPurpose.search),
                ),
              );
            },
          ),

        const Divider(),

        ListTile(
          leading: const Icon(Icons.download_rounded),
          title: const Text('Download APP:'),
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
    );
    return AppScaffold(
      floatingActionButton: !kIsWeb
          ? FloatingActionButton(
              tooltip: 'Skanuj',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ScanScreen(purpose: ScanPurpose.search),
                ),
              ),
              child: const Icon(Icons.qr_code_scanner, size: 32),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      title: 'Panel',
      showBackOnMobile: false,
      body: body,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: _signOut,
        ),
      ],

      // floatingActionButton: !kIsWeb
      //     ? FloatingActionButton(
      //         tooltip: 'Skanuj',
      //         onPressed: () => Navigator.of(
      //           context,
      //         ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
      //         child: const Icon(Icons.qr_code_scanner, size: 32),
      //       )
      //     : null,
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // bottomNavigationBar: SafeArea(
      //   child: BottomAppBar(
      //     shape: const CircularNotchedRectangle(),
      //     notchMargin: 6,
      //     child: Padding(
      //       padding: const EdgeInsets.symmetric(horizontal: 32),
      //       child: Row(
      //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //         children: [
      //           IconButton(
      //             tooltip: 'Inwentaryzacja',
      //             icon: const Icon(Icons.inventory_2),
      //             onPressed: () => Navigator.of(context).push(
      //               MaterialPageRoute(
      //                 builder: (_) => InventoryListScreen(isAdmin: isAdmin),
      //               ),
      //             ),
      //           ),
      //           IconButton(
      //             tooltip: 'Klienci',
      //             icon: const Icon(Icons.group),
      //             onPressed: () => Navigator.of(context).push(
      //               MaterialPageRoute(
      //                 builder: (_) => CustomerListScreen(isAdmin: isAdmin),
      //               ),
      //             ),
      //           ),
      //         ],
      //       ),
      //     ),
      //   ),
      // ),
    );
  }
}
