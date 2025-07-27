// lib/screens/contact_detail_screen.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  Future<void> _addProject(BuildContext context, String customerId) async {
    String title = '';
    DateTime? startDate;
    DateTime? estimatedEndDate;
    String costStr = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nowy Projekt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nazwa projektu',
                  ),
                  onChanged: (v) => title = v.trim(),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        startDate == null
                            ? 'Data rozpoczęcia'
                            : DateFormat('dd.MM.yyyy').format(startDate!),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final dt = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('pl', 'PL'),
                        );
                        if (dt != null) setState(() => startDate = dt);
                      },
                      child: const Text('Wybierz'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        estimatedEndDate == null
                            ? 'Oszac. data zakończenia'
                            : DateFormat(
                                'dd.MM.yyyy',
                              ).format(estimatedEndDate!),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final dt = await showDatePicker(
                          context: ctx,
                          initialDate: estimatedEndDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('pl', 'PL'),
                        );
                        if (dt != null) setState(() => estimatedEndDate = dt);
                      },
                      child: const Text('Wybierz'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Oszacowany koszt',
                    prefixText: 'PLN ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => costStr = v.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (title.isEmpty) return;
                final data = <String, dynamic>{
                  'title': title,
                  'status': 'draft',
                  'customerId': customerId,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser!.uid,
                  'items': <Map<String, dynamic>>[],
                  if (startDate != null)
                    'startDate': Timestamp.fromDate(startDate!),
                  if (estimatedEndDate != null)
                    'estimatedEndDate': Timestamp.fromDate(estimatedEndDate!),
                };
                final cost = double.tryParse(costStr.replaceAll(',', '.'));
                if (cost != null) data['estimatedCost'] = cost;

                await FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customerId)
                    .collection('projects')
                    .add(data);

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Utwórz'),
            ),
          ],
        ),
      ),
    );
  }

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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Brak danych.')));
        }

        final data = snapshot.data!.data()!;
        final custId = data['linkedCustomerId'] as String?;
        final name = data['name'] ?? 'Brak imienia';

        return DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              final tabController = DefaultTabController.of(context)!;
              return AnimatedBuilder(
                animation: tabController,
                builder: (context, _) => AppScaffold(
                  title: '',
                  titleWidget: GestureDetector(
                    onLongPress: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddContactScreen(
                            isAdmin: isAdmin,
                            contactId: contactId,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  centreTitle: true,
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'Szczegóły'),
                      Tab(text: 'Kontakty'),
                    ],
                  ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.centerDocked,
                  floatingActionButton: custId == null
                      ? null
                      : (tabController.index == 0
                            ? FloatingActionButton(
                                tooltip: 'Dodaj Projekt',
                                child: const Icon(Icons.playlist_add),
                                onPressed: () => _addProject(context, custId),
                              )
                            : FloatingActionButton(
                                tooltip: 'Dodaj Kontakt',
                                child: const Icon(Icons.person_add_alt),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddContactScreen(
                                        isAdmin: isAdmin,
                                        linkedCustomerId: custId,
                                      ),
                                    ),
                                  );
                                },
                              )),

                  body: TabBarView(
                    children: [
                      // === Szczegóły Tab ===
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (data['photoUrl'] != null) ...[
                              Center(
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundImage: NetworkImage(
                                    data['photoUrl'],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // AutoSizeText(
                            //   data['contactType'] ?? '-',
                            //   style: const TextStyle(
                            //     fontWeight: FontWeight.bold,
                            //   ),
                            //   minFontSize: 15,
                            // ),
                            // const Divider(),
                            Text(
                              data['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((data['phone'] ?? '').isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: InkWell(
                                      onTap: () => openUri(
                                        Uri.parse('tel:${data['phone']}'),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.phone,
                                            size: 18,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            data['phone'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            data['contactType'] ?? '-',
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if ((data['phone'] ?? '').isNotEmpty &&
                                    (data['email'] ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                ],
                                if ((data['email'] ?? '').isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: InkWell(
                                      onTap: () => openUri(
                                        Uri.parse('mailto:${data['email']}'),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.email,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            data['email'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // if ((data['address'] ?? '').isNotEmpty)
                            //   ListTile(
                            //     leading: const Icon(Icons.location_on),
                            //     title: Text(data['address']),
                            //     onTap: () => openUri(
                            //       Uri.parse('geo:0,0?q=${Uri.encodeComponent(data['address'])}'),
                            //       mode: LaunchMode.externalApplication,
                            //     ),
                            //   ),
                            const SizedBox(height: 15),
                            Divider(),

                            AutoSizeText(
                              'Projekty',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              minFontSize: 15,
                            ),

                            if (custId == null) ...[
                              const Text('Brak powiązany klient'),
                            ] else
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: FirebaseFirestore.instance
                                    .collectionGroup('projects')
                                    .where('customerId', isEqualTo: custId)
                                    .orderBy('createdAt', descending: true)
                                    .snapshots(),
                                builder: (context, projSnap) {
                                  if (projSnap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                  if (projSnap.hasError) {
                                    return Text('Error: ${projSnap.error}');
                                  }
                                  final docs = projSnap.data?.docs ?? [];
                                  if (docs.isEmpty) {
                                    return const Text('Brak projektów.');
                                  }
                                  return ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: docs.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(),
                                    itemBuilder: (_, i) {
                                      final d = docs[i];
                                      final proj = d.data();
                                      return ListTile(
                                        title: Text(proj['title'] ?? '—'),
                                        subtitle: Text(
                                          DateFormat(
                                            'dd.MM.yyyy • HH:mm',
                                            'pl_PL',
                                          ).format(
                                            (proj['createdAt'] as Timestamp)
                                                .toDate()
                                                .toLocal(),
                                          ),
                                        ),
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ProjectEditorScreen(
                                              customerId: custId,
                                              projectId: d.id,
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
                      ),

                      // === Kontakty Tab ===
                      custId == null
                          ? const Center(
                              child: Text('Brak powiązanego klienta'),
                            )
                          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('contacts')
                                  .where('linkedCustomerId', isEqualTo: custId)
                                  .orderBy('name')
                                  .snapshots(),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snap.hasError) {
                                  return Center(
                                    child: Text('Error: ${snap.error}'),
                                  );
                                }
                                final docs = snap.data!.docs
                                    .where((doc) => doc.id != contactId)
                                    .toList();
                                if (docs.isEmpty) {
                                  return const Center(
                                    child: Text('Brak kontaktów.'),
                                  );
                                }
                                return ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final contact = docs[i].data();
                                    final phone =
                                        (contact['phone'] ?? '') as String;
                                    final email =
                                        (contact['email'] ?? '') as String;

                                    return ListTile(
                                      title: Text(
                                        contact['name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),

                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (phone.isNotEmpty) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 20,
                                              ),
                                              child: InkWell(
                                                onTap: () => openUri(
                                                  Uri.parse('tel:$phone'),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.phone,
                                                      size: 18,
                                                      color: Colors.green,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      phone,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (phone.isNotEmpty &&
                                              email.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                          ],
                                          if (email.isNotEmpty) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 20,
                                              ),
                                              child: InkWell(
                                                onTap: () => openUri(
                                                  Uri.parse('mailto:$email'),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.email,
                                                      size: 18,
                                                      color: Colors.blue,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      email,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),

                                      trailing: Text(
                                        contact['contactType'] ?? '-',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ContactDetailScreen(
                                            contactId: docs[i].id,
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

                  // bottomNavigationBar: SafeArea(
                  //   child: BottomAppBar(
                  //     shape: const CircularNotchedRectangle(),
                  //     notchMargin: 6,
                  //     child: Padding(
                  //       padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  //       child: Row(
                  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //         children: [
                  //           IconButton(
                  //             tooltip: 'Klienci',
                  //             icon: const Icon(Icons.people),
                  //             onPressed: () => Navigator.of(context).push(
                  //               MaterialPageRoute(
                  //                 builder: (_) => CustomerListScreen(isAdmin: isAdmin),
                  //               ),
                  //             ),
                  //           ),
                  //           IconButton(
                  //             tooltip: 'Projekty',
                  //             icon: const Icon(Icons.folder_open),
                  //             onPressed: custId == null
                  //                 ? null
                  //                 : () => Navigator.of(context).push(
                  //                     MaterialPageRoute(
                  //                       builder: (_) => ContactDetailScreen(
                  //                         contactId: contactId,
                  //                         isAdmin: isAdmin,
                  //                       ),
                  //                     ),
                  //                   ),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
