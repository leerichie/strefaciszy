// lib/screens/contact_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
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
    super.key,
    required this.contactId,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final docRef = FirebaseFirestore.instance
        .collection('contacts')
        .doc(contactId);

    Future<void> openUri(
      Uri uri, {
      LaunchMode mode = LaunchMode.platformDefault,
    }) async {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not launch $uri')),
        );
      }
    }

    final titleStreamWidget =
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              return const Text('...');
            }
            final data = snapshot.data!.data()!;
            return Text(data['name'] ?? 'Brak imienia');
          },
        );

    return AppScaffold(
      title: '',
      titleWidget: titleStreamWidget,
      centreTitle: true,

      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black,
            child: IconButton(
              icon: const Icon(Icons.home),
              color: Colors.white,
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
          ),
        ),
      ],

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
          final customerId = data['linkedCustomerId'] as String?;
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
                    onTap: () =>
                        openUri(Uri(scheme: 'tel', path: data['phone'])),
                  ),

                if ((data['mobile'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.smartphone),
                    title: Text(data['mobile']),
                    onTap: () =>
                        openUri(Uri(scheme: 'tel', path: data['mobile'])),
                  ),

                if ((data['email'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: Text(data['email']),
                    onTap: () =>
                        openUri(Uri(scheme: 'mailto', path: data['email'])),
                  ),

                if ((data['address'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(data['address']),
                    onTap: () => openUri(
                      Uri.parse(
                        'geo:0,0?q=${Uri.encodeComponent(data['address'])}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),

                if ((data['www'] ?? '').isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(data['www']),
                    onTap: () {
                      var raw = data['www']! as String;
                      if (!raw.startsWith('http')) raw = 'https://$raw';
                      openUri(
                        Uri.parse(raw),
                        mode: LaunchMode.externalApplication,
                      );
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
                Text(
                  'Projekty:',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),

                if (customerId == null) ...[
                  const Text('Brak powiązany klient'),
                ] else
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collectionGroup('projects')
                        // .where('contactId', isEqualTo: contactId)
                        .where('customerId', isEqualTo: customerId)
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
                            // subtitle: Text('Status: ${proj['status']}'),
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
