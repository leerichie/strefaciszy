// lib/screens/contact_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:strefa_ciszy/screens/add_contact_screen.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'project_editor_screen.dart';

class ContactDetailScreen extends StatelessWidget {
  final String contactId;
  final bool isAdmin;

  const ContactDetailScreen({
    Key? key,
    required this.contactId,
    this.isAdmin = false,
  }) : super(key: key);

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('contacts')
        .doc(contactId);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Dane kontaktowe'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const MainMenuScreen(role: 'admin'),
                ),
                (route) => false,
              );
            },
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AddContactScreen(isAdmin: isAdmin, contactId: contactId),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Usuń kontakt?'),
                  content: const Text('Na pewno usunać kontakt?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Anuluj'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Usuń'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await docRef.delete();
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Brak danych.'));
          }
          final data = snapshot.data!.data()!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data['photoUrl'] != null) ...[
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: NetworkImage(data['photoUrl']),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  data['name'] ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Typ kontaktu: ${data['contactType'] ?? '-'}'),
                const Divider(),
                if ((data['phone'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: Text(data['phone']),
                    onTap: () => _launchUrl('tel:${data['phone']}'),
                  ),
                if ((data['mobile'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.smartphone),
                    title: Text(data['mobile']),
                    onTap: () => _launchUrl('tel:${data['mobile']}'),
                  ),
                if ((data['email'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: Text(data['email']),
                    onTap: () => _launchUrl('mailto:${data['email']}'),
                  ),
                if ((data['address'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(data['address']),
                    onTap: () => _launchUrl(
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(data['address'])}',
                    ),
                  ),
                if ((data['www'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(data['www']),
                    onTap: () {
                      var url = data['www']!;
                      if (!url.startsWith('http')) url = 'https://$url';
                      _launchUrl(url);
                    },
                  ),
                if ((data['note'] ?? '').isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'Notatka:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(data['note']),
                ],
                const SizedBox(height: 24),
                // projects ??
                Text(
                  'Projekty:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('projects')
                      .where('contactId', isEqualTo: contactId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, projSnap) {
                    if (projSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (projSnap.hasError) {
                      return Center(child: Text('Error: ${projSnap.error}'));
                    }
                    final projDocs = projSnap.data!.docs;
                    if (projDocs.isEmpty) {
                      return const Text('Brak projektów.');
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: projDocs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final proj = projDocs[i].data();
                        return ListTile(
                          title: Text(proj['title'] ?? '—'),
                          subtitle: Text('Status: ${proj['status']}'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProjectEditorScreen(
                                customerId: proj['customerId'],
                                projectId: projDocs[i].id,
                                isAdmin: isAdmin,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Edytuj Kontakt',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AddContactScreen(isAdmin: isAdmin, contactId: contactId),
          ),
        ),
        child: const Icon(Icons.edit),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.people),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerListScreen(isAdmin: isAdmin),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Skanuj',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
