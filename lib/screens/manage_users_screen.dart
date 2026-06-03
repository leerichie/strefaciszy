// lib/screens/manage_users_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

import '../services/user_functions.dart';

class _AppPalette {
  static const bodyFont = 'Bose (Regular)';
  static const headlineFont = 'Bose-Headline (Bold)';
  static const surface = Colors.white;
  static const bg = Color(0xFFF4F6F7);
  static const line = Color(0xFFD4DCE0);
  static const text = Color(0xFF1E2B2F);
  static const muted = Color(0xFF607176);
  static const brand = Color(0xFF2574A9);
  static const danger = Color(0xFFE04747);
}

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final UserFunctions _svc = UserFunctions();
  late Future<List<Map<String, dynamic>>> _usersFuture;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final user = FirebaseAuth.instance.currentUser!;
    final idToken = await user.getIdTokenResult();
    var isAdmin = idToken.claims?['admin'] == true;

    if (!isAdmin) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? {};
      final role = (data['role'] ?? '').toString().toLowerCase();
      isAdmin = data['isAdmin'] == true || role == 'admin';
    }

    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }

    if (!isAdmin) {
      throw Exception('Admin only');
    }

    final users = await _svc.listUsers();
    users.sort((a, b) {
      final an = ((a['name'] as String?) ?? '').toLowerCase();
      final bn = ((b['name'] as String?) ?? '').toLowerCase();
      if (an != bn) return an.compareTo(bn);

      final ae = ((a['email'] as String?) ?? '').toLowerCase();
      final be = ((b['email'] as String?) ?? '').toLowerCase();
      return ae.compareTo(be);
    });

    return users;
  }

  void _reload() {
    setState(() {
      _usersFuture = _loadUsers();
    });
  }

  Future<void> _showAddDialog() async {
    String name = '', email = '', pwd = '', role = 'user';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontFamily: _AppPalette.headlineFont,
          fontWeight: FontWeight.w800,
          color: _AppPalette.text,
          fontSize: 17,
          letterSpacing: 0,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _AppPalette.bodyFont,
          color: _AppPalette.muted,
          fontSize: 14,
        ),
        title: const Text('Dodaj pracownik'),

        content: DismissKeyboard(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Imię i nazwisko',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _AppPalette.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: _AppPalette.brand,
                          width: 1.5,
                        ),
                      ),
                      labelStyle: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.muted,
                      ),
                      hintStyle: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.muted,
                      ),
                    ),
                    onChanged: (v) => name = v.trim(),
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _AppPalette.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: _AppPalette.brand,
                          width: 1.5,
                        ),
                      ),
                      labelStyle: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.muted,
                      ),
                      hintStyle: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.muted,
                      ),
                    ),
                    onChanged: (v) => email = v,
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Hasło',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _AppPalette.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: _AppPalette.brand,
                          width: 1.5,
                        ),
                      ),
                      labelStyle: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.muted,
                      ),
                      hintStyle: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.muted,
                      ),
                    ),
                    obscureText: true,
                    onChanged: (v) => pwd = v,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Dostęp',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _AppPalette.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: _AppPalette.brand,
                          width: 1.5,
                        ),
                      ),
                      labelStyle: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.muted,
                      ),
                      hintStyle: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.muted,
                      ),
                    ),
                    initialValue: role,
                    items: ['admin', 'user']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => role = v ?? 'user',
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _AppPalette.muted),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppPalette.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _svc.createUser(name, email.trim(), pwd, role);
                _reload();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error creating user: $e')),
                );
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    String name = user['name'] ?? '',
        email = user['email'] ?? '',
        password = '',
        role = user['role'] ?? 'user';
    // final isAdmin = role == 'admin';
    final nameController = TextEditingController(text: name);
    final emailController = TextEditingController(text: email);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontFamily: _AppPalette.headlineFont,
          fontWeight: FontWeight.w800,
          color: _AppPalette.text,
          fontSize: 17,
          letterSpacing: 0,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _AppPalette.bodyFont,
          color: _AppPalette.muted,
          fontSize: 14,
        ),
        title: const Text('Edytuj użytkownika'),
        content: DismissKeyboard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Imię',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _AppPalette.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: _AppPalette.brand,
                      width: 1.5,
                    ),
                  ),
                  labelStyle: const TextStyle(
                    fontFamily: _AppPalette.bodyFont,
                    color: _AppPalette.muted,
                  ),
                  hintStyle: const TextStyle(
                    fontFamily: _AppPalette.bodyFont,
                    color: _AppPalette.muted,
                  ),
                ),
                controller: nameController,
                onChanged: (v) => name = v.trim(),
              ),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _AppPalette.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: _AppPalette.brand,
                      width: 1.5,
                    ),
                  ),
                  labelStyle: const TextStyle(
                    fontFamily: _AppPalette.bodyFont,
                    color: _AppPalette.muted,
                  ),
                  hintStyle: const TextStyle(
                    fontFamily: _AppPalette.bodyFont,
                    color: _AppPalette.muted,
                  ),
                ),
                controller: emailController,
                onChanged: (v) => email = v.trim(),
              ),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Nowe hasło',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _AppPalette.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: _AppPalette.brand,
                      width: 1.5,
                    ),
                  ),
                  labelStyle: const TextStyle(
                    fontFamily: _AppPalette.bodyFont,
                    color: _AppPalette.muted,
                  ),
                  hintStyle: const TextStyle(
                    fontFamily: _AppPalette.bodyFont,
                    color: _AppPalette.muted,
                  ),
                ),
                obscureText: true,
                onChanged: (v) => password = v,
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Dostęp',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _AppPalette.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: _AppPalette.brand,
                      width: 1.5,
                    ),
                  ),
                  labelStyle: const TextStyle(
                    fontFamily: _AppPalette.bodyFont,
                    color: _AppPalette.muted,
                  ),
                  hintStyle: const TextStyle(
                    fontFamily: _AppPalette.bodyFont,
                    color: _AppPalette.muted,
                  ),
                ),
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('admin')),
                  DropdownMenuItem(value: 'user', child: Text('user')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    role = v;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _AppPalette.muted),
            child: const Text('Anuluj'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppPalette.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Zapisz'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final currentUser = FirebaseAuth.instance.currentUser;
                final roleChanged = role != user['role'];
                await _svc.updateUserDetails(
                  uid: user['uid'],
                  name: name != user['name'] ? name : null,
                  email: email != user['email'] ? email : null,
                  password: password.isNotEmpty ? password : null,
                  role: roleChanged ? role : null,
                );
                if (roleChanged && currentUser?.uid == user['uid']) {
                  await currentUser!.getIdTokenResult(true);
                }
                _reload();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving user: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: _AppPalette.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: _AppPalette.headlineFont,
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: _AppPalette.text,
            letterSpacing: 0,
          ),
        ),
      ),
      child: AppScaffold(
        floatingActionButton: FloatingActionButton(
          backgroundColor: _AppPalette.brand,
          foregroundColor: Colors.white,
          tooltip: 'Dodaj pracownika',
          onPressed: _isAdmin ? _showAddDialog : null,
          child: const Icon(Icons.person_add_alt),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        centreTitle: true,
        title: 'Users',
        titleWidget: const Text('USERS'),
        appBarFlexibleSpace: const _HeaderGradient(),
        showBackOnWeb: true,
        backgroundColor: _AppPalette.bg,
        actions: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0)),
        ],

        body: DismissKeyboard(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _usersFuture,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _AppPalette.brand),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading users:\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: _AppPalette.bodyFont,
                        color: _AppPalette.danger,
                      ),
                    ),
                  ),
                );
              }
              final users = snap.data!;
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    'Nie znaleziono użytkowników.',
                    style: TextStyle(
                      fontFamily: _AppPalette.bodyFont,
                      color: _AppPalette.muted,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: users.length,
                itemBuilder: (ctx, i) {
                  final u = users[i];
                  final name = (u['name'] as String?) ?? '—';
                  final email = (u['email'] as String?) ?? '';
                  final role = (u['role'] as String?) ?? 'user';
                  final isAdminRole = role == 'admin';
                  final initials = _initials(u['name']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _AppPalette.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // avatar
                            Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    _AppPalette.brand,
                                    Color(0xFF1E5D88),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: _AppPalette.headlineFont,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // name + email + role badge
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: _AppPalette.headlineFont,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: _AppPalette.text,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontFamily: _AppPalette.bodyFont,
                                      fontSize: 13,
                                      color: _AppPalette.muted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAdminRole
                                          ? _AppPalette.brand.withValues(
                                              alpha: 0.12,
                                            )
                                          : _AppPalette.bg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: _AppPalette.headlineFont,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: isAdminRole
                                            ? _AppPalette.brand
                                            : _AppPalette.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // action buttons
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: _AppPalette.brand,
                              ),
                              tooltip: 'Edytuj',
                              onPressed: () => _showEditUserDialog(u),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: _AppPalette.danger,
                              ),
                              tooltip: 'Usuń',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                    backgroundColor: _AppPalette.surface,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    titleTextStyle: const TextStyle(
                                      fontFamily: _AppPalette.headlineFont,
                                      fontWeight: FontWeight.w800,
                                      color: _AppPalette.text,
                                      fontSize: 17,
                                      letterSpacing: 0,
                                    ),
                                    contentTextStyle: const TextStyle(
                                      fontFamily: _AppPalette.bodyFont,
                                      color: _AppPalette.muted,
                                      fontSize: 14,
                                    ),
                                    title: const Text('Usuń użytkownika?'),
                                    content: Text(email),
                                    actions: [
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: _AppPalette.muted,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx2, false),
                                        child: const Text('Anuluj'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _AppPalette.danger,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx2, true),
                                        child: const Text('Usuń'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await _svc.deleteUser(u['uid']);
                                    _reload();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error deleting user: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ); // Theme + AppScaffold
  }
}

class _HeaderGradient extends StatelessWidget {
  const _HeaderGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFE9ECEF), Color(0xFFA9C6D8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}
