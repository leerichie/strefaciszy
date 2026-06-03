import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strefa_ciszy/screens/admin_event_logs_screen.dart';
import 'package:strefa_ciszy/screens/approval_screen.dart';
import 'package:strefa_ciszy/screens/archives_screen.dart';
import 'package:strefa_ciszy/screens/chat_list_screen.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/login_screen.dart';
import 'package:strefa_ciszy/screens/my_day_screen.dart';
import 'package:strefa_ciszy/screens/projects_list_screen.dart';
import 'package:strefa_ciszy/screens/reports_daily.dart';
import 'package:strefa_ciszy/screens/shopping_list_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:strefa_ciszy/services/app_update_service.dart';
import 'customer_list_screen.dart';
import 'manage_users_screen.dart';
import 'scan_screen.dart';

class _MenuPalette {
  static const bodyFont = 'Bose (Regular)';
  static const surface = Colors.white;
  static const line = Color(0xFFD4DCE0);
  static const text = Color(0xFF1E2B2F);
  static const muted = Color(0xFF607176);
  static const brand = Color(0xFF2574A9);
  static const danger = Color(0xFFE04747);
}

class MainMenuScreen extends StatefulWidget {
  final String role;
  const MainMenuScreen({super.key, required this.role});

  @override
  _MainMenuScreenState createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with WidgetsBindingObserver {
  String get role => widget.role;
  bool get isAdmin => role == 'admin';
  String _version = '';
  DateTime? _lastUpdateCheckAt;
  bool _updateCheckRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runUpdateCheck();
    });
    _loadVersion();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate(context);
    });
  }

  bool get _isReportsUser {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    return email == 'info@strefaciszy.net';
  }

  bool get canSeeReportsRW => isAdmin || _isReportsUser;

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

  Future<void> _runUpdateCheck() async {
    if (!mounted || _updateCheckRunning) return;

    final now = DateTime.now();

    if (_lastUpdateCheckAt != null &&
        now.difference(_lastUpdateCheckAt!) < const Duration(minutes: 5)) {
      return;
    }

    _updateCheckRunning = true;
    _lastUpdateCheckAt = now;

    try {
      await AppUpdateService.checkForUpdate(context);
    } finally {
      _updateCheckRunning = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runUpdateCheck();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  static const _titleStyle = TextStyle(
    fontFamily: _MenuPalette.bodyFont,
    color: _MenuPalette.text,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  static const _subtitleStyle = TextStyle(
    fontFamily: _MenuPalette.bodyFont,
    color: _MenuPalette.muted,
    fontSize: 13,
  );

  static const _divider = Divider(
    height: 1,
    thickness: 1,
    color: _MenuPalette.line,
  );

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final fabClearance =
            MediaQuery.of(context).padding.bottom +
            kFloatingActionButtonMargin +
            56.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, fabClearance),
          child: ConstrainedBox(
            // minHeight fills the screen; if items exceed it the list scrolls
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - fabClearance - 8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isAdmin)
                  ListTile(
                    leading: const Icon(
                      Icons.admin_panel_settings,
                      color: _MenuPalette.brand,
                    ),
                    title: const Text('Użytkownicy', style: _titleStyle),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManageUsersScreen(),
                      ),
                    ),
                  ),

                if (AdminEventLogsScreen.isAllowed()) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.manage_search,
                      color: Colors.amber,
                    ),
                    title: const Text('LOGS', style: _titleStyle),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminEventLogsScreen(),
                      ),
                    ),
                  ),
                  _divider,
                ],

                if (canSeeReportsRW) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.summarize_outlined,
                      color: _MenuPalette.brand,
                    ),
                    title: const Text('Raporty RW', style: _titleStyle),
                    // subtitle: const Text(
                    //   'Wygenerować raport za dowolny dzień',
                    //   style: _subtitleStyle,
                    // ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReportsDailyScreen(),
                      ),
                    ),
                  ),
                  _divider,
                ],

                ListTile(
                  leading: const Icon(
                    Icons.calendar_today_outlined,
                    color: _MenuPalette.brand,
                  ),
                  title: const Text('Mój Dzień', style: _titleStyle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyDayScreen()),
                  ),
                ),

                if (isAdmin) ...[
                  _divider,
                  ListTile(
                    leading: const Icon(
                      Icons.archive,
                      color: _MenuPalette.brand,
                    ),
                    title: const Text('Archive', style: _titleStyle),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ArchivesScreen()),
                    ),
                  ),
                ],

                _divider,

                ListTile(
                  leading: const Icon(
                    Icons.inventory_2,
                    color: _MenuPalette.brand,
                  ),
                  title: const Text('Magazyn', style: _titleStyle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InventoryListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.people_alt_outlined,
                    color: _MenuPalette.brand,
                  ),
                  title: const Text('Klienci', style: _titleStyle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.contact_phone_outlined,
                    color: _MenuPalette.brand,
                  ),
                  title: const Text('Kontakty', style: _titleStyle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ContactsListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),

                ListTile(
                  leading: const Icon(
                    Icons.work_outline,
                    color: _MenuPalette.brand,
                  ),
                  title: const Text('Projekty', style: _titleStyle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProjectsListScreen(isAdmin: true),
                    ),
                  ),
                ),

                uid == null
                    ? ListTile(
                        leading: const Icon(
                          Icons.chat,
                          color: _MenuPalette.brand,
                        ),
                        title: const Text('Chat', style: _titleStyle),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChatListScreen(),
                          ),
                        ),
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
                            final v = d.data()['unread_$uid'];
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
                                color: _MenuPalette.danger,
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
                            leading: const Icon(
                              Icons.chat,
                              color: _MenuPalette.brand,
                            ),
                            title: const Text('Chat', style: _titleStyle),
                            trailing: badge(),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ChatListScreen(),
                              ),
                            ),
                          );
                        },
                      ),

                ListTile(
                  leading: const Icon(
                    Icons.shopping_cart_outlined,
                    color: _MenuPalette.brand,
                  ),
                  title: const Text('Zakupy', style: _titleStyle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ShoppingListScreen(),
                    ),
                  ),
                ),

                if (isAdmin)
                  StreamBuilder<bool>(
                    stream: _isApproverStream(),
                    builder: (context, snap) {
                      final allowed = snap.data ?? false;
                      if (!allowed) return const SizedBox.shrink();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _divider,
                          ListTile(
                            leading: const Icon(
                              Icons.verified_user,
                              color: _MenuPalette.brand,
                            ),
                            title: const Text(
                              'Fakturowanie (Wf-Mag)',
                              style: _titleStyle,
                            ),
                            // subtitle: const Text(
                            //   'zatwierdzenie towar do fakturowanie',
                            //   style: _subtitleStyle,
                            // ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ApprovalScreen(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Skanuj',
        backgroundColor: _MenuPalette.brand,
        foregroundColor: _MenuPalette.surface,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ScanScreen(purpose: ScanPurpose.search),
          ),
        ),
        child: const Icon(Icons.qr_code_scanner, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      title: '',
      titleWidget: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;

          final double logoHeight = maxWidth < 360
              ? 18
              : maxWidth < 420
              ? 22
              : 26;

          return Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _version,
                    style: const TextStyle(
                      fontFamily: _MenuPalette.bodyFont,
                      fontSize: 13,
                      color: _MenuPalette.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              Center(
                child: Transform.translate(
                  offset: const Offset(10, 0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth * 0.5),
                    child: Image.asset(
                      'assets/images/strefa_ciszy_logo.png',
                      height: logoHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 48),
              ),
            ],
          );
        },
      ),
      showBackOnMobile: false,
      showPersistentDrawerOnWeb: true,
      backgroundColor: _MenuPalette.surface,

      body: Stack(
        children: [
          body,
          // dev logo — bottom-right, respects safe area
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            right: 12,
            child: GestureDetector(
              onTap: () async {
                final url = Uri.parse('https://ashleyrichards.tech');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Image.asset(
                'assets/images/dev_logo_PILL.png',
                width: 64,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // download icons — right edge, vertically centred
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: false,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: _MenuPalette.surface.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 10,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _storeIconButton(
                        assetPath: 'assets/images/android_logo.png',
                        tooltip: 'Pobierz APK (Android)',
                        onTap: () => _downloadApp(context),
                        size: 36,
                      ),
                      const SizedBox(height: 4),
                      _storeIconButton(
                        assetPath: 'assets/images/apple_ios_logo.png',
                        tooltip: 'Otwórz TestFlight (iOS)',
                        onTap: () => _openTestFlight(context),
                        size: 36,
                      ),
                    ],
                  ),
                ),
              ),
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
