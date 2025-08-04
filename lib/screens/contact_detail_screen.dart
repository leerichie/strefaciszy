// lib/screens/contact_detail_screen.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:strefa_ciszy/screens/add_contact_screen.dart';
import 'project_editor_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final String contactId;
  final bool isAdmin;

  const ContactDetailScreen({
    super.key,
    required this.contactId,
    this.isAdmin = false,
  });

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _user = FirebaseAuth.instance.currentUser!;
  late final _favProjCol = FirebaseFirestore.instance
      .collection('users')
      .doc(_user.uid)
      .collection('favouriteProjects');

  final Set<String> _favProjectIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavouriteProjects();
  }

  Future<void> _loadFavouriteProjects() async {
    final snap = await _favProjCol.get();
    setState(() {
      _favProjectIds.addAll(snap.docs.map((d) => d.id));
    });
  }

  Future<void> _toggleFavouriteProjects(
    String projectId,
    String title,
    String customerId,
  ) async {
    if (_favProjectIds.contains(projectId)) {
      await _favProjCol.doc(projectId).delete();
      setState(() => _favProjectIds.remove(projectId));
    } else {
      await _favProjCol.doc(projectId).set({
        'title': title,
        'customerId': customerId,
      });
      setState(() => _favProjectIds.add(projectId));
    }
  }

  Future<void> _showProjectDialog({
    required BuildContext context,
    required String customerId,
    String? projectId,
    Map<String, dynamic>? existingData,
  }) async {
    final titleCtrl = TextEditingController(text: existingData?['title'] ?? '');
    final costCtrl = TextEditingController(
      text: existingData?['estimatedCost']?.toString() ?? '',
    );
    DateTime? startDate = existingData?['startDate']?.toDate();
    DateTime? endDate = existingData?['estimatedEndDate']?.toDate();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(projectId == null ? 'Nowy Projekt' : 'Edytuj Projekt'),
          content: DismissKeyboard(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa projektu',
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          endDate == null
                              ? 'Data zakończenie'
                              : DateFormat('dd.MM.yyyy').format(endDate!),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final dt = await showDatePicker(
                            context: ctx,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            locale: const Locale('pl', 'PL'),
                          );
                          if (dt != null) setState(() => endDate = dt);
                        },
                        child: const Text('Wybierz'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: costCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Oszacowany koszt',
                      prefixText: 'PLN ',
                    ),
                    keyboardType: TextInputType.number,
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
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final data = <String, dynamic>{
                  'title': title,
                  'status': existingData?['status'] ?? 'draft',
                  'customerId': customerId,
                  'createdAt':
                      existingData?['createdAt'] ??
                      FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser!.uid,
                  if (startDate != null)
                    'startDate': Timestamp.fromDate(startDate!),
                  if (endDate != null)
                    'estimatedEndDate': Timestamp.fromDate(endDate!),
                  if (double.tryParse(costCtrl.text.replaceAll(',', '.')) !=
                      null)
                    'estimatedCost': double.parse(
                      costCtrl.text.replaceAll(',', '.'),
                    ),
                };

                final col = FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customerId)
                    .collection('projects');

                if (projectId == null) {
                  await col.add(data);
                } else {
                  await col.doc(projectId).set(data, SetOptions(merge: true));
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(projectId == null ? 'Utwórz' : 'Zapisz'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditContactDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> docSnap,
  ) async {
    final data = docSnap.data();

    String name = data['name'] as String? ?? '';
    String phone = data['phone'] as String? ?? '';
    String email = data['email'] as String? ?? '';
    String type = data['contactType'] as String? ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edytuj kontakt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Imię i nazwisko'),
                onChanged: (v) => name = v.trim(),
              ),
              TextFormField(
                initialValue: phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
                keyboardType: TextInputType.phone,
                onChanged: (v) => phone = v.trim(),
              ),
              TextFormField(
                initialValue: email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => email = v.trim(),
              ),
              TextFormField(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Typ kontaktu'),
                onChanged: (v) => type = v.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              await docSnap.reference.update({
                'name': name,
                'phone': phone,
                'email': email,
                'contactType': type,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  String formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat(
        'dd.MM.yyyy • HH:mm',
        'pl_PL',
      ).format(ts.toDate().toLocal());
    }
    return 'Brak daty';
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final docRef = FirebaseFirestore.instance
        .collection('contacts')
        .doc(widget.contactId);

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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data()!;
        final custId = data['linkedCustomerId'] as String?;
        final name = data['name'] ?? 'Brak imienia';
        final extraNumbers = (data['extraNumbers'] is List)
            ? List<String>.from(data['extraNumbers'])
            : <String>[];

        return DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              final tabController = DefaultTabController.of(context);
              return AnimatedBuilder(
                animation: tabController,
                builder: (context, _) => AppScaffold(
                  title: '',
                  titleWidget: GestureDetector(
                    onLongPress: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddContactScreen(
                            isAdmin: widget.isAdmin,
                            contactId: widget.contactId,
                            forceAsContact: true,
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
                                onPressed: () => _showProjectDialog(
                                  context: context,
                                  customerId: custId,
                                ),
                              )
                            : FloatingActionButton(
                                tooltip: 'Dodaj Kontakt',
                                child: const Icon(Icons.person_add_alt),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddContactScreen(
                                        isAdmin: widget.isAdmin,
                                        linkedCustomerId: custId,
                                        forceAsContact: true,
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

                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  data['contactType'] ?? '-',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                            Divider(),
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
                                          // const Spacer(),
                                          // Text(
                                          //   data['contactType'] ?? '-',
                                          //   style: const TextStyle(
                                          //     fontSize: 15,
                                          //   ),
                                          // ),
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
                                // Drugi numer
                                if (extraNumbers.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: InkWell(
                                      onTap: () => openUri(
                                        Uri.parse('tel:${extraNumbers.first}'),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.phone_android,
                                            size: 18,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            extraNumbers.first,
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                // Adres
                                if ((data['address'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  ListTile(
                                    contentPadding: const EdgeInsets.only(
                                      left: 20,
                                    ),
                                    leading: const Icon(Icons.location_on),
                                    title: Text(data['address']!),
                                    onTap: () => openUri(
                                      Uri.parse(
                                        'geo:0,0?q=${Uri.encodeComponent(data['address']!)}',
                                      ),
                                    ),
                                  ),
                                ],

                                // WWW
                                if ((data['www'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  ListTile(
                                    contentPadding: const EdgeInsets.only(
                                      left: 20,
                                    ),
                                    leading: const Icon(Icons.link),
                                    title: Text(data['www']!),
                                    onTap: () => openUri(
                                      Uri.parse(
                                        data['www']!.startsWith('http')
                                            ? data['www']!
                                            : 'https://${data['www']}',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  ),
                                ],

                                // Notatka
                                if ((data['note'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Text(
                                      data['note']!,
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 15),
                            Divider(),

                            AutoSizeText(
                              'Projekty',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              minFontSize: 15,
                            ),

                            if (custId != null)
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: FirebaseFirestore.instance
                                    .collectionGroup('projects')
                                    .where('customerId', isEqualTo: custId)
                                    .orderBy('createdAt', descending: true)
                                    .snapshots(),
                                builder: (ctx, projSnap) {
                                  if (projSnap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final docs = projSnap.data?.docs ?? [];
                                  if (docs.isEmpty) {
                                    return const Text('Brak projektów.');
                                  }

                                  return NotificationListener<
                                    ScrollNotification
                                  >(
                                    onNotification: (notif) {
                                      if (notif is ScrollStartNotification) {
                                        FocusScope.of(context).unfocus();
                                      }
                                      return false;
                                    },
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      itemCount: docs.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (_, i) {
                                        final d = docs[i];
                                        final pm = d.data();
                                        final title =
                                            pm['title'] as String? ?? '—';
                                        final dateText = formatTimestamp(
                                          pm['createdAt'],
                                        );
                                        final isFav = _favProjectIds.contains(
                                          d.id,
                                        );

                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                              ),
                                          title: Text(
                                            title,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(dateText),
                                          onTap: () =>
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ProjectEditorScreen(
                                                        customerId: custId,
                                                        projectId: d.id,
                                                        isAdmin: widget.isAdmin,
                                                      ),
                                                ),
                                              ),
                                          onLongPress: widget.isAdmin
                                              ? () => _showProjectDialog(
                                                  context: context,
                                                  customerId: custId,
                                                  projectId: d.id,
                                                  existingData: pm,
                                                )
                                              : null,
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // ★ / ☆
                                              IconButton(
                                                icon: Icon(
                                                  isFav
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                ),
                                                onPressed: () =>
                                                    _toggleFavouriteProjects(
                                                      d.id,
                                                      title,
                                                      custId,
                                                    ),
                                              ),

                                              // RW count badge
                                              FutureBuilder<QuerySnapshot>(
                                                future: d.reference
                                                    .collection('rw_documents')
                                                    .get(),
                                                builder: (ctx2, s2) {
                                                  if (s2.connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    );
                                                  }
                                                  final cnt =
                                                      s2.data?.docs.length ?? 0;
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'RW: $cnt',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),

                                              // delete
                                              if (widget.isAdmin) ...[
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () async {
                                                    final ok = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx3) => AlertDialog(
                                                        title: const Text(
                                                          'Usuń projekt?',
                                                        ),
                                                        content: Text(title),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx3,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Anuluj',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx3,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              'Usuń',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (ok == true) {
                                                      await d.reference
                                                          .delete();
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Projekt usunięty',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
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
                                    .where((doc) => doc.id != widget.contactId)
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
                                              email.isNotEmpty)
                                            const SizedBox(height: 4),
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
                                        style: const TextStyle(fontSize: 15),
                                      ),

                                      onTap: () => _showEditContactDialog(
                                        context,
                                        docs[i],
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
