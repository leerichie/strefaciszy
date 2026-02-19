// lib/screens/project_contacts_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/services/user_functions.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:strefa_ciszy/widgets/chip_contact_role.dart';
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
  String? _mainContactId; // główny
  bool _loadingMain = true;

  String? _projectTitle;
  bool _loadingProjectTitle = true;

  bool _isSelectingContacts = false;
  final Set<String> _selectedContactEmails = {};

  final UserFunctions _userSvc = UserFunctions();

  bool _kadraLoading = true;
  bool _kadraExpanded = false;
  List<Map<String, dynamic>> _kadraUsers = [];

  @override
  void initState() {
    super.initState();
    _loadMainContact();
    _loadKadraUsers();
    _loadProjectTitle();
  }

  Future<void> _loadProjectTitle() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .get();

      setState(() {
        _projectTitle = snap.data()?['title'] as String?;
        _loadingProjectTitle = false;
      });
    } catch (_) {
      setState(() => _loadingProjectTitle = false);
    }
  }

  Future<void> _loadKadraUsers() async {
    try {
      final users = await _userSvc.listUsers();
      setState(() {
        _kadraUsers = users;
        _kadraLoading = false;
      });
    } catch (_) {
      setState(() => _kadraLoading = false);
    }
  }

  Widget _buildKadraSection(ThemeData theme) {
    if (_kadraLoading) {
      return const ListTile(
        title: Text('STREFA ZIOMKI'),
        trailing: SizedBox(
          width: 18,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_kadraUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Image.asset(
            'assets/images/strefa_ciszy_logo.png',
            width: 150,
            height: 100,
            fit: BoxFit.contain,
          ),
          title: const Text(
            ' - ZIOMKI - ',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          trailing: Icon(
            _kadraExpanded ? Icons.expand_less : Icons.expand_more,
          ),
          onTap: () {
            setState(() => _kadraExpanded = !_kadraExpanded);
          },
        ),
        if (_kadraExpanded)
          ..._kadraUsers.map((u) {
            final email = (u['email'] ?? '') as String;
            final name = (u['name'] ?? '') as String;
            final canSelect = email.isNotEmpty;
            final selected = _selectedContactEmails.contains(email);

            return ListTile(
              leading: _isSelectingContacts
                  ? Checkbox(
                      value: canSelect && selected,
                      onChanged: canSelect
                          ? (val) {
                              final now = val ?? false;
                              setState(() {
                                if (now) {
                                  _selectedContactEmails.add(email);
                                } else {
                                  _selectedContactEmails.remove(email);
                                }
                              });
                            }
                          : null,
                    )
                  // : const Icon(Icons.person_outline),
                  : Image.asset(
                      'assets/images/strefa_S.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
              title: Text(
                name.isEmpty ? email : name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: email.isEmpty ? null : Text(email),
              onTap: !_isSelectingContacts || !canSelect
                  ? null
                  : () {
                      setState(() {
                        if (selected) {
                          _selectedContactEmails.remove(email);
                        } else {
                          _selectedContactEmails.add(email);
                        }
                      });
                    },
            );
          }),
      ],
    );
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
      ).showSnackBar(const SnackBar(content: Text('No contacts selected')));
      return;
    }

    final emails = _selectedContactEmails
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final uri = Uri(
      scheme: 'mailto',
      path: '',
      queryParameters: {
        'to': emails.join(','),
        // optional:
        // 'subject': '...',
        // 'body': '...',
      },
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open email client: $uri')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot open email client: $uri')));
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
      titleWidget: Text(
        (_projectTitle == null || _projectTitle!.isEmpty)
            ? 'Kontakty projektu'
            : 'Kontakty - ${_projectTitle!}',
        style: const TextStyle(fontSize: 20),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
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
                initialProjectId: widget.projectId,
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
                // for (final doc in all) {
                //   final data = doc.data();
                //   final linkedCustomerId = data['linkedCustomerId'] as String?;
                //   final linkedProjects = (data['linkedProjectIds'] is List)
                //       ? List<String>.from(data['linkedProjectIds'])
                //       : <String>[];

                //   final directCustomer = linkedCustomerId == widget.customerId;
                //   final projectLink = linkedProjects.contains(widget.projectId);

                //   if (directCustomer || projectLink) {
                //     related.add(doc);
                //   }
                // }

                // if (related.isEmpty) {
                //   return const Center(
                //     child: Text('Brak kontaktów powiązanych'),
                //   );
                // }
                for (final doc in all) {
                  final data = doc.data();
                  final linkedCustomerId = data['linkedCustomerId'] as String?;
                  final linkedProjects = (data['linkedProjectIds'] is List)
                      ? List<String>.from(data['linkedProjectIds'])
                      : <String>[];

                  final projectLink = linkedProjects.contains(widget.projectId);

                  final isMainCustomerContact =
                      linkedCustomerId == widget.customerId &&
                      doc.id == _mainContactId;

                  if (projectLink || isMainCustomerContact) {
                    related.add(doc);
                  }
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

                final theme = Theme.of(context);
                final hasKadraRow = _kadraUsers.isNotEmpty || _kadraLoading;
                final totalRows = docs.length + (hasKadraRow ? 1 : 0);

                return ListView.separated(
                  itemCount: totalRows,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    if (hasKadraRow && index == 1) {
                      return _buildKadraSection(theme);
                    }

                    final docIndex = (hasKadraRow && index > 1)
                        ? index - 1
                        : index;
                    final doc = docs[docIndex];
                    final contact = doc.data();
                    final phone = (contact['phone'] ?? '') as String;
                    final email = (contact['email'] ?? '') as String;
                    final canSelect = email.isNotEmpty;
                    final selected = _selectedContactEmails.contains(email);
                    final isMainContact = doc.id == _mainContactId;
                    final List<String> extraTypes = List<String>.from(
                      contact['extraContactTypes'] ?? const <String>[],
                    );

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
                            if (extraTypes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: extraTypes
                                        .map(
                                          (t) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            child: ContactRoleChip(label: t),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
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
