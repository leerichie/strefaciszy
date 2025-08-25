import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:strefa_ciszy/screens/aprroval_screen.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/login_screen.dart';
import 'package:strefa_ciszy/services/admin_api.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/utils/stock_normalizer.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

import 'customer_list_screen.dart';
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
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  bool get _isLee {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    return email == 'leerichie@wp.pl';
  }

  Stream<bool> _isApproverStream() {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    return FirebaseFirestore.instance
        .collection('config')
        .doc('security')
        .snapshots()
        .map((doc) {
          final arr = List<String>.from(
            doc.data()?['approverEmails'] ?? const [],
          );
          return arr.map((e) => e.toLowerCase()).contains(email);
        })
        .handleError((_) => false);
  }

  /// DEV:

  // Future<void> _normalizeAll() async {
  //   if (!mounted) return;

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Starting full normalization…')),
  //   );

  //   try {
  //     const pageSize = 200;
  //     int offset = 0;
  //     int staged = 0;

  //     while (true) {
  //       final items = await ApiService.fetchProducts(
  //         limit: pageSize,
  //         offset: offset,
  //       );
  //       if (items.isEmpty) break;

  //       for (final it in items) {
  //         final norm = StockNormalizer.normalize(it);
  //         await AdminApi.stageOne(normalized: norm, who: 'lee');
  //         staged++;
  //         await Future.delayed(const Duration(milliseconds: 5));
  //       }

  //       offset += items.length;
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text('Staged $staged so far…')));
  //     }

  //     final pending = await AdminApi.pendingIds();
  //     int applied = 0;
  //     const chunk = 200;
  //     for (int i = 0; i < pending.length; i += chunk) {
  //       final part = pending.sublist(
  //         i,
  //         (i + chunk > pending.length) ? pending.length : i + chunk,
  //       );
  //       await AdminApi.applyIds(part, who: 'lee');
  //       applied += part.length;
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Applied $applied / ${pending.length}…')),
  //       );
  //     }

  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Normalization complete. Staged: $staged • Applied: $applied',
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text('Error: $e')));
  //   }
  // }

  Future<void> _loadVersion() async {
    if (kIsWeb) {
      try {
        final jsonStr = await rootBundle.loadString('version.json');
        final data = json.decode(jsonStr);
        setState(() {
          _version = 'v.${data["version"]} _${data["build_number"]}';
        });
        return;
      } catch (e) {
        setState(() => _version = 'v.unknown');
        return;
      }
    }

    // Mobile/Desktop fallback
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v.${info.version} _${info.buildNumber}';
    });
  }

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
        Image.asset('assets/images/strefa_ciszy_logo.png', width: 200),

        const SizedBox(height: 24),

        // DEV btn
        // if (_isLee && isAdmin) ...[
        //   const Divider(),
        //   ListTile(
        //     leading: const Icon(Icons.auto_fix_high),
        //     title: const Text('Normalize (name • category • producer)'),
        //     subtitle: const Text('Applies to all in WAPRO'),
        //     onTap: _normalizeAll,
        //   ),
        //   const Divider(),
        // ],

        ///////
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

        StreamBuilder<bool>(
          stream: _isApproverStream(),
          builder: (context, snap) {
            final allowed = snap.data ?? false;
            if (!allowed) return const SizedBox.shrink();
            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: const Text('Potwierdzenia (WAPRO)'),
                  subtitle: const Text('Dokonanie zmiań w bazie danych'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ApprovalScreen()),
                    );
                  },
                ),
                const Divider(),
              ],
            );
          },
        ),

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

      title: '',
      titleWidget: Text(_version, style: TextStyle(fontSize: 15)),

      showBackOnMobile: false,

      body: Stack(
        children: [
          body,
          Positioned(
            bottom: 60,
            right: 20,
            child: Image.asset(
              'assets/images/Lee_logo_app_dev.png',
              width: 80,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),

      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: _signOut,
        ),
      ],
    );
  }
}
