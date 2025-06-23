// lib/screens/manage_users_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_functions.dart';

import 'inventory_list_screen.dart';
import 'customer_list_screen.dart';
import 'scan_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final UserFunctions _svc = UserFunctions();
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final user = FirebaseAuth.instance.currentUser!;
    await user.reload();
    final idToken = await user.getIdTokenResult(true);
    print(
      '🔥 refreshed claims – amIAdmin = ${idToken.claims?['admin'] == true}',
    );
    return _svc.listUsers();
  }

  void _reload() => setState(() => _usersFuture = _loadUsers());

  Future<void> _showAddDialog() async {
    String name = '', email = '', pwd = '', role = 'user';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj pracownik'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Imię i nazwisko',
                  ),
                  onChanged: (v) => name = v.trim(),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  onChanged: (v) => email = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Hasło'),
                  obscureText: true,
                  onChanged: (v) => pwd = v,
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Dostęp'),
                  value: role,
                  items: ['admin', 'user']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => role = v ?? 'user',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _svc.createUser(name, email.trim(), pwd, role);
                await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
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
    final isAdmin = role == 'admin';
    final nameController = TextEditingController(text: name);
    final emailController = TextEditingController(text: email);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edytuj użytkownika'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Imię'),
              controller: nameController,
              onChanged: (v) => name = v.trim(),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
              controller: emailController,
              onChanged: (v) => email = v.trim(),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Nowe hasło'),
              obscureText: true,
              onChanged: (v) => password = v,
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Dostęp'),
              value: role,
              items: [
                'admin',
                'user',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: isAdmin ? null : (v) => role = v ?? role,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Anuluj'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text('Zapisz'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _svc.updateUserDetails(
                  uid: user['uid'],
                  name: name != user['name'] ? name : null,
                  email: email != user['email'] ? email : null,
                  password: password.isNotEmpty ? password : null,
                  role: role != user['role'] ? role : null,
                );
                await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = true; // or derive from claims if needed

    return Scaffold(
      // ── AppBar ──
      appBar: AppBar(title: const Text('Zarządzaj użytkownikami')),

      // ── Body ──
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error loading users:\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          final users = snap.data!;
          if (users.isEmpty) {
            return const Center(child: Text('Nie znaleziono użytkowników.'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, i) {
              final u = users[i];
              return ListTile(
                title: Text(u['name'] ?? '—'),
                subtitle: Text('${u['email']}\nDostęp: ${u['role']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edytuj użytkownika',
                      onPressed: () => _showEditUserDialog(u),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Usuń użytkownika',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            title: Text('Usuń ${u['email']}?'),
                            actions: [
                              TextButton(
                                child: const Text('Anuluj'),
                                onPressed: () => Navigator.pop(ctx2, false),
                              ),
                              ElevatedButton(
                                child: const Text('Usuń'),
                                onPressed: () => Navigator.pop(ctx2, true),
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
                                content: Text('Error deleting user: $e'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        tooltip: 'Dodaj pracownika',
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Inwentaryzacja',
                  icon: const Icon(Icons.inventory_2),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InventoryListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.group),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustomerListScreen(isAdmin: true),
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
