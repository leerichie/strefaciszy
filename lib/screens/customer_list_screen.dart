// lib/screens/customer_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _col = FirebaseFirestore.instance.collection('customers');

  Future<void> _addCustomer() async {
    String name = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Customer'),
        content: TextField(
          decoration: InputDecoration(labelText: 'Customer Name'),
          onChanged: (v) => name = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) {
                final uid = DateTime.now().millisecondsSinceEpoch.toString();
                _col.add({
                  'name': name,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(ctx);
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
      appBar: AppBar(title: const Text('Customers')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _col.orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No customers yet.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final ts = d['createdAt'] as Timestamp?;
              final date = ts != null
                  ? DateFormat(
                      'dd.MM.yyyy HH:mm',
                      'pl_PL',
                    ).format(ts.toDate().toLocal())
                  : '';
              return ListTile(
                title: Text(d['name'] ?? '—'),
                subtitle: ts != null ? Text(date) : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(customerId: d.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Customer',
        onPressed: _addCustomer,
        child: Icon(Icons.person_add),
      ),
    );
  }
}
