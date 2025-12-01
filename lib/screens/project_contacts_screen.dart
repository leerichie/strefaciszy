// lib/screens/project_contacts_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_contact_screen.dart';
import 'contact_detail_screen.dart';

class ProjectContactsScreen extends StatefulWidget {
  final String customerId;
  final String projectId;
  final bool isAdmin;

  const ProjectContactsScreen({
    super.key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
  });

  @override
  State<ProjectContactsScreen> createState() => _ProjectContactsScreenState();
}

class _ProjectContactsScreenState extends State<ProjectContactsScreen> {
  String? _mainContactId; // kontakt główny
  bool _loadingMain = true;

  bool _isSelectingContacts = false;
  final Set<String> _selectedContactEmails = {};

  @override
  void initState() {
    super.initState();
    _loadMainContact();
  }

  Future<void> _loadMainContact() async {
    try {
      final customerRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId);
      final projRef = customerRef.collection('projects').doc(widget.projectId);

      final custSnap = await customerRef.get();
      final projSnap = await projRef.get();

      String? contactId = custSnap.data()?['contactId'] as String?;

      contactId ??= projSnap.data()?['contactId'] as String?;

      setState(() {
        _mainContactId = contactId;
        _loadingMain = false;
      });
    } catch (_) {
      setState(() => _loadingMain = false);
    }
  }

  Future<void> _sendEmailToSelected() async {
    if (_selectedContactEmails.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nie wybrane kontaktów')));
      return;
    }

    final toParam = _selectedContactEmails.join(';');
    final uri = Uri.parse('mailto:$toParam');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie można otworzyć klienta email: $uri')),
      );
    }
  }

  Future<void> _openUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nie można otworzyć: $uri')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    return AppScaffold(
      showBackOnWeb: true,
      centreTitle: true,
      title: '',
      titleWidget: const Text(
        'Kontakty projektu',
        style: TextStyle(fontSize: 20),
      ),
      actions: [
        if (_isSelectingContacts)
          IconButton(
            tooltip: 'Wyślij email do zaznaczonych',
            icon: const Icon(Icons.send),
            onPressed: _sendEmailToSelected,
          ),
        IconButton(
          tooltip: _isSelectingContacts ? 'Zakończ wybór' : 'Zaznacz kontakty',
          icon: Icon(
            _isSelectingContacts ? Icons.check_box : Icons.email_outlined,
          ),
          onPressed: () {
            setState(() {
              if (_isSelectingContacts) {
                _isSelectingContacts = false;
                _selectedContactEmails.clear();
              } else {
                _isSelectingContacts = true;
              }
            });
          },
        ),
      ],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Dodaj Kontakt',
        child: const Icon(Icons.person_add_alt),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddContactScreen(
                isAdmin: widget.isAdmin,
                linkedCustomerId: widget.customerId,
                forceAsContact: true,
              ),
            ),
          );
        },
      ),
      body: _loadingMain
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('contacts')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Błąd ładowania  ',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }

                final all = snapshot.data?.docs ?? [];

                final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                related = [];
                for (final doc in all) {
                  final data = doc.data();
                  final linkedCustomerId = data['linkedCustomerId'] as String?;
                  final linkedProjects = (data['linkedProjectIds'] is List)
                      ? List<String>.from(data['linkedProjectIds'])
                      : <String>[];

                  final directCustomer = linkedCustomerId == widget.customerId;
                  final projectLink = linkedProjects.contains(widget.projectId);

                  if (directCustomer || projectLink) {
                    related.add(doc);
                  }
                }

                if (related.isEmpty) {
                  return const Center(
                    child: Text('Brak kontaktów powiązanych'),
                  );
                }

                QueryDocumentSnapshot<Map<String, dynamic>> mainDoc;

                if (_mainContactId != null && _mainContactId!.isNotEmpty) {
                  try {
                    mainDoc = related.firstWhere((d) => d.id == _mainContactId);
                  } catch (_) {
                    mainDoc = related.first;
                  }
                } else {
                  mainDoc = related.first;
                }

                final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [
                  mainDoc,
                  ...related.where((d) => d.id != mainDoc.id),
                ];

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final contact = doc.data();
                    final phone = (contact['phone'] ?? '') as String;
                    final email = (contact['email'] ?? '') as String;
                    final canSelect = email.isNotEmpty;
                    final selected = _selectedContactEmails.contains(email);
                    final isMainContact = doc.id == _mainContactId;
                    final theme = Theme.of(context);

                    return Container(
                      decoration: isMainContact
                          ? BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(
                                0.06,
                              ),
                              border: Border(
                                left: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 4,
                                ),
                              ),
                            )
                          : null,
                      child: ListTile(
                        leading: _isSelectingContacts
                            ? Checkbox(
                                value: canSelect && selected,
                                onChanged: canSelect
                                    ? (val) {
                                        final nowSelected = val ?? false;

                                        if (!nowSelected &&
                                            !selected &&
                                            !canSelect) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Kontakt nie ma emailu przeciez :/',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        setState(() {
                                          if (nowSelected) {
                                            _selectedContactEmails.add(email);
                                          } else {
                                            _selectedContactEmails.remove(
                                              email,
                                            );
                                          }
                                        });
                                      }
                                    : null,
                              )
                            : null,
                        title: Row(
                          children: [
                            if (isMainContact)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'GŁÓWNY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                contact['name'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: isMainContact
                                      ? theme.colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (phone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: InkWell(
                                  onTap: _isSelectingContacts
                                      ? null
                                      : () => _openUri(Uri.parse('tel:$phone')),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        phone,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (phone.isNotEmpty && email.isNotEmpty)
                              const SizedBox(height: 4),
                            if (email.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: InkWell(
                                  onTap: _isSelectingContacts
                                      ? null
                                      : () => _openUri(
                                          Uri.parse('mailto:$email'),
                                        ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.email,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          email,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            (contact['contactType'] ?? '-')
                                .toString()
                                .replaceAll(' ', '\n'),
                            textAlign: TextAlign.right,
                            softWrap: true,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        onTap: _isSelectingContacts
                            ? () {
                                if (email.isEmpty) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Ten kontakt nie ma emailu',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  if (selected) {
                                    _selectedContactEmails.remove(email);
                                  } else {
                                    _selectedContactEmails.add(email);
                                  }
                                });
                              }
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ContactDetailScreen(
                                      contactId: doc.id,
                                      isAdmin: widget.isAdmin,
                                    ),
                                  ),
                                );
                              },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
