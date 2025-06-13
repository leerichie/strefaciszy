// lib/screens/manage_users_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_functions.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    print("🔑 currentUser.uid = ${user?.uid}");
    if (user != null) {
      final token = await user.getIdToken(true);
      print("🔑 got new ID token: ${token?.substring(0, 50)}…");
    }
    return _svc.listUsers();
  }

  void _reload() {
    setState(() {
      _usersFuture = _loadUsers();
    });
  }

  Future<void> _showAddDialog() async {
    String email = '';
    String pwd = '';
    String role = 'user';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Email'),
              onChanged: (v) => email = v,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
              onChanged: (v) => pwd = v,
            ),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Role'),
              value: role,
              items: [
                'admin',
                'user',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => role = v ?? 'user',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _svc
                  .createUser(email.trim(), pwd, role)
                  .then((_) => _reload())
                  .catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating user: $e')),
                    );
                  });
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Users')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Employee',
        onPressed: _showAddDialog,
        child: Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading users:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          final users = snapshot.data;
          if (users == null || users.isEmpty) {
            return Center(child: Text('No users found.'));
          }

          // 1) Count how many admins exist
          final adminCount = users.where((u) => u['role'] == 'admin').length;

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (ctx, i) {
              final u = users[i];
              final isAdmin = u['role'] == 'admin';
              // 2) If they’re the only admin, protect them
              final isOnlyAdmin = isAdmin && adminCount == 1;

              return ListTile(
                title: Text(u['email'] ?? '—'),
                subtitle: Text('Role: ${u['role']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TOGGLE ROLE BUTTON
                    IconButton(
                      icon: Icon(Icons.edit),
                      tooltip: isOnlyAdmin
                          ? 'Cannot demote the only admin'
                          : 'Toggle role',
                      onPressed: isOnlyAdmin
                          ? null
                          : () async {
                              final newRole = isAdmin ? 'user' : 'admin';
                              try {
                                await _svc.updateUserRole(u['uid'], newRole);
                                _reload();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error updating role: $e'),
                                  ),
                                );
                              }
                            },
                    ),

                    // DELETE BUTTON
                    IconButton(
                      icon: Icon(Icons.delete),
                      tooltip: isOnlyAdmin
                          ? 'Cannot delete the only admin'
                          : 'Delete user',
                      onPressed: isOnlyAdmin
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx2) => AlertDialog(
                                  title: Text('Delete ${u['email']}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx2, false),
                                      child: Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx2, true),
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
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
    );
  }
}
