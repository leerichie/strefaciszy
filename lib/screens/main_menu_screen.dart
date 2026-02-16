import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strefa_ciszy/screens/approval_screen.dart';
import 'package:strefa_ciszy/screens/archives_screen.dart';
import 'package:strefa_ciszy/screens/chat_list_screen.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/login_screen.dart';
import 'package:strefa_ciszy/screens/projects_list_screen.dart';
import 'package:strefa_ciszy/screens/reports_daily.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

import 'customer_list_screen.dart';
import 'manage_users_screen.dart';
import 'scan_screen.dart';

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

  Widget _storeIconButton({
    required String assetPath,
    required String tooltip,
    required VoidCallback onTap,
    double size = 44,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Future<void> _openTestFlight(BuildContext context) async {
    final url = Uri.parse('https://testflight.apple.com/join/zwNuDeCk');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie można otworzyć TestFlight')),
      );
    }
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Image.asset('assets/images/strefa_ciszy_logo.png', width: 200),
        const SizedBox(height: 24),

        if (_isLee && isAdmin) ...[
          // const DebugReserveButton(),
          const SizedBox(height: 16),
          const Divider(),
        ],

        if (isAdmin) ...[
          ListTile(
            visualDensity: const VisualDensity(
              vertical: -4,
            ), // tighten gap between rows

            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Użytkownicy'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
            ),
          ),
          ListTile(
            visualDensity: const VisualDensity(vertical: -4),

            leading: const Icon(Icons.summarize_outlined),
            title: const Text('Raporty RW'),
            subtitle: const Text('Wygenerować raport za dowolny dzień'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportsDailyScreen()),
              );
            },
          ),
          ListTile(
            visualDensity: const VisualDensity(vertical: -4),

            leading: const Icon(Icons.archive),
            title: const Text('Archive'),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ArchivesScreen()));
            },
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

        ListTile(
          leading: const Icon(Icons.work_outline),
          title: const Text("Projekty"),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProjectsListScreen(isAdmin: true),
              ),
            );
          },
        ),

        uid == null
            ? ListTile(
                leading: const Icon(Icons.chat),
                title: const Text("Chat"),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  );
                },
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('members', arrayContains: uid)
                    .snapshots(),
                builder: (ctx, snap) {
                  final docs = snap.data?.docs ?? const [];

                  int total = 0;
                  for (final d in docs) {
                    final data = d.data();
                    final v = data['unread_$uid'];
                    if (v is int) {
                      total += v;
                    } else if (v is num) {
                      total += v.toInt();
                    }
                  }

                  Widget badge() {
                    if (total <= 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        total > 99 ? '99+' : '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  return ListTile(
                    leading: const Icon(Icons.chat),
                    title: const Text("Chat"),
                    trailing: badge(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChatListScreen(),
                        ),
                      );
                    },
                  );
                },
              ),

        // ListTile(
        //   leading: const Icon(Icons.qr_code_scanner),
        //   title: const Text('Skanuj'),
        //   onTap: () {
        //     Navigator.of(context).push(
        //       MaterialPageRoute(
        //         builder: (_) => const ScanScreen(purpose: ScanPurpose.search),
        //       ),
        //     );
        //   },
        // ),
        const Divider(),

        // if (isAdmin) ...[
        //   ListTile(
        //     leading: const Icon(Icons.playlist_add_check_circle_outlined),
        //     title: const Text('Rezerwacje (test)'),
        //     subtitle: const Text('Reserve → Confirm → Invoiced/Release'),
        //     onTap: () => Navigator.of(context).push(
        //       MaterialPageRoute(
        //         builder: (_) => const ReservationTesterScreen(),
        //       ),
        //     ),
        //   ),
        //   const Divider(),
        // ],
        StreamBuilder<bool>(
          stream: _isApproverStream(),
          builder: (context, snap) {
            final allowed = snap.data ?? false;
            if (!allowed) return const SizedBox.shrink();
            return Column(
              children: [
                ListTile(
                  visualDensity: const VisualDensity(vertical: -4),

                  leading: const Icon(Icons.verified_user),
                  title: const Text('Fakturowanie (Wf-Mag)'),
                  subtitle: const Text('zatwierdzenie towar do fakturowanie'),
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
          title: const Text('Tapnij aby pobrac:'),
          // subtitle: const Text('Android APK / iOS TestFlight'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _storeIconButton(
                assetPath: 'assets/images/android_logo.png',
                tooltip: 'Pobierz APK (Android)',
                onTap: () => _downloadApp(context),
                size: 44,
              ),
              const SizedBox(width: 10),
              _storeIconButton(
                assetPath: 'assets/images/apple_ios_logo.png',
                tooltip: 'Otwórz TestFlight (iOS)',
                onTap: () => _openTestFlight(context),
                size: 80,
              ),
            ],
          ),
        ),
      ],
    );

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Skanuj',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ScanScreen(purpose: ScanPurpose.search),
          ),
        ),
        child: const Icon(Icons.qr_code_scanner, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      title: '',
      titleWidget: Text(_version, style: const TextStyle(fontSize: 15)),
      showBackOnMobile: false,
      showPersistentDrawerOnWeb: false,
      backgroundColor: Colors.white,

      body: Stack(
        children: [
          body,
          Positioned(
            bottom: 60,
            right: 20,
            child: Image.asset(
              'assets/images/dev_logo_PILL.png',
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
