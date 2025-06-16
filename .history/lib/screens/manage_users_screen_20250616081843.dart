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
      final result = await user.getIdTokenResult(true);
      print("🔥 Custom claims = ${result.claims}");
    }

    return _svc.listUsers();
  }

  void _reload() {
    setState(() {
      _usersFuture = _loadUsers();
    });
  }

  Future<void> _showAddDialog() async {
    String name = '';
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
              decoration: InputDecoration(labelText: 'Name'),
              onChanged: (v) => name = v.trim(),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Email'),
              onChanged: (v) => email = v.trim(),
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
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: Text('Create'),
            onPressed: () {
              Navigator.pop(ctx);
              _svc
                  .createUser(name, email, pwd, role)
                  .then((_) => _reload())
                  .catchError((e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    String name = user['name'] ?? '';
    String email = user['email'] ?? '';
    String pwd = '';
    String role = user['role'] ?? 'user';
    final isAdmin = role == 'admin';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${user['email']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: name),
              decoration: InputDecoration(labelText: 'Name'),
              onChanged: (v) => name = v.trim(),
            ),
            TextField(
              controller: TextEditingController(text: email),
              decoration: InputDecoration(labelText: 'Email'),
              onChanged: (v) => email = v.trim(),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'New Password'),
              obscureText: true,
              onChanged: (v) => pwd = v.trim(),
            ),
            DropdownButtonFormField<String>(
              value: role,
              decoration: InputDecoration(labelText: 'Role'),
              items: [
                'admin',
                'user',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: isAdmin ? null : (v) => role = v ?? 'user',
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () {
              Navigator.pop(ctx);
              _svc
                  .updateUser(
                    uid: user['uid'],
                    name: name,
                    email: email,
                    password: pwd.isEmpty ? null : pwd,
                    role: role,
                  )
                  .then((_) => _reload())
                  .catchError((e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Update error: $e')));
                  });
            },
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
        tooltip: 'Add User',
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
                'Error:\n${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(child: Text('No users found.'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (ctx, i) {
              final u = users[i];
              return ListTile(
                title: Text(u['email'] ?? '—'),
                subtitle: Text('Role: ${u['role']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      tooltip: 'Edit',
                      onPressed: () => _showEditDialog(u),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      tooltip: 'Delete',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            title: Text('Delete ${u['email']}?'),
                            actions: [
                              TextButton(
                                child: Text('Cancel'),
                                onPressed: () => Navigator.pop(ctx2, false),
                              ),
                              ElevatedButton(
                                child: Text('Delete'),
                                onPressed: () => Navigator.pop(ctx2, true),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          _svc.deleteUser(u['uid']).then((_) => _reload());
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
