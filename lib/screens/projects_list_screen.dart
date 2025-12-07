import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

import 'project_editor_screen.dart';

enum _ProjectSort { newest, oldest, nameAZ, nameZA }

class ProjectsListScreen extends StatefulWidget {
  final bool isAdmin;
  const ProjectsListScreen({super.key, this.isAdmin = false});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  late final Future<Map<String, String>> _customersFuture;

  _ProjectSort _sort = _ProjectSort.newest;

  @override
  void initState() {
    super.initState();
    _customersFuture = _loadCustomers();
  }

  Future<Map<String, String>> _loadCustomers() async {
    final snap = await FirebaseFirestore.instance.collection('customers').get();
    return {
      for (final d in snap.docs)
        d.id: (d.data()['name'] as String?) ?? 'Nieznany klient',
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy');

    return AppScaffold(
      title: 'Projekty',
      showBackOnWeb: true,
      centreTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Szukaj projektu…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Wyczyść',
                onPressed: () {
                  if (_searchController.text.isEmpty) return;
                  _searchController.clear();
                  setState(() {
                    _search = '';
                  });
                },
              ),
              PopupMenuButton<_ProjectSort>(
                tooltip: 'Sortuj',
                icon: const Icon(Icons.sort),
                onSelected: (value) {
                  setState(() {
                    _sort = value;
                  });
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: _ProjectSort.newest,
                    child: Text('Najnowszy'),
                  ),
                  PopupMenuItem(
                    value: _ProjectSort.oldest,
                    child: Text('Najstarszy'),
                  ),
                  PopupMenuItem(value: _ProjectSort.nameAZ, child: Text('A-Z')),
                  PopupMenuItem(value: _ProjectSort.nameZA, child: Text('Z-A')),
                ],
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _customersFuture,
        builder: (ctx, custSnap) {
          if (custSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final customerNames = custSnap.data ?? {};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collectionGroup('projects')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, projSnap) {
              if (projSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (projSnap.hasError) {
                return Center(child: Text('Błąd: ${projSnap.error}'));
              }

              final docs = projSnap.data!.docs;

              // Build list of projects
              final projects = docs
                  .map((d) {
                    final data = d.data();
                    final title = (data['title'] as String?) ?? '';
                    final createdAt = (data['createdAt'] as Timestamp?)
                        ?.toDate();
                    final customerId = d.reference.parent.parent?.id ?? '';

                    return _ProjectItem(
                      id: d.id,
                      title: title,
                      customerId: customerId,
                      createdAt: createdAt,
                    );
                  })
                  .where((p) {
                    if (_search.isEmpty) return true;
                    return p.title.toLowerCase().contains(_search);
                  })
                  .toList();

              if (projects.isEmpty) {
                return const Center(child: Text('Brak projektów.'));
              }

              // Group by customer
              final Map<String, List<_ProjectItem>> grouped = {};
              for (final p in projects) {
                grouped.putIfAbsent(p.customerId, () => []).add(p);
              }

              final epoch = DateTime.fromMillisecondsSinceEpoch(0);

              // helpers: newest / oldest date in a group
              DateTime newestOf(List<_ProjectItem> items) =>
                  items.map((p) => p.createdAt ?? epoch).fold(epoch, (prev, d) {
                    if (d.isAfter(prev)) return d;
                    return prev;
                  });

              DateTime oldestOf(List<_ProjectItem> items) => items
                  .map((p) => p.createdAt ?? epoch)
                  .fold(DateTime.now(), (prev, d) {
                    if (d.isBefore(prev)) return d;
                    return prev;
                  });

              // sort customer groups according to current sort mode
              final entries = grouped.entries.toList()
                ..sort((a, b) {
                  final an = customerNames[a.key] ?? '';
                  final bn = customerNames[b.key] ?? '';

                  switch (_sort) {
                    case _ProjectSort.nameAZ:
                      return an.compareTo(bn);
                    case _ProjectSort.nameZA:
                      return bn.compareTo(an);
                    case _ProjectSort.newest:
                      return newestOf(b.value).compareTo(newestOf(a.value));
                    case _ProjectSort.oldest:
                      return oldestOf(a.value).compareTo(oldestOf(b.value));
                  }
                });

              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (ctx, index) {
                  final entry = entries[index];
                  final customerId = entry.key;
                  final customerName =
                      customerNames[customerId] ?? 'Nieznany klient';

                  // copy + sort projects INSIDE this customer group
                  final customerProjects = [...entry.value]
                    ..sort((a, b) {
                      switch (_sort) {
                        case _ProjectSort.newest:
                          return (b.createdAt ?? epoch).compareTo(
                            a.createdAt ?? epoch,
                          );
                        case _ProjectSort.oldest:
                          return (a.createdAt ?? epoch).compareTo(
                            b.createdAt ?? epoch,
                          );
                        case _ProjectSort.nameAZ:
                          return a.title.toLowerCase().compareTo(
                            b.title.toLowerCase(),
                          );
                        case _ProjectSort.nameZA:
                          return b.title.toLowerCase().compareTo(
                            a.title.toLowerCase(),
                          );
                      }
                    });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 1),
                        child: Text(
                          customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 15,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      ...customerProjects.map((p) {
                        final dateText = p.createdAt != null
                            ? dateFmt.format(p.createdAt!)
                            : null;
                        return ListTile(
                          dense: false,
                          title: Text(
                            p.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: dateText != null ? Text(dateText) : null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProjectEditorScreen(
                                  customerId: p.customerId,
                                  projectId: p.id,
                                  isAdmin: widget.isAdmin,
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      const Divider(height: 1),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ProjectItem {
  final String id;
  final String title;
  final String customerId;
  final DateTime? createdAt;

  _ProjectItem({
    required this.id,
    required this.title,
    required this.customerId,
    required this.createdAt,
  });
}
