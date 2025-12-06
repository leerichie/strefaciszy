import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

import 'project_editor_screen.dart';

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
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
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

              projects.sort((a, b) {
                final ad =
                    a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bd =
                    b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bd.compareTo(ad);
              });

              // Group by customer
              final Map<String, List<_ProjectItem>> grouped = {};
              for (final p in projects) {
                grouped.putIfAbsent(p.customerId, () => []).add(p);
              }

              final entries = grouped.entries.toList()
                ..sort((a, b) {
                  final an = customerNames[a.key] ?? '';
                  final bn = customerNames[b.key] ?? '';
                  return an.compareTo(bn);
                });

              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (ctx, index) {
                  final entry = entries[index];
                  final customerId = entry.key;
                  final customerName =
                      customerNames[customerId] ?? 'Nieznany klient';
                  final customerProjects = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // customer header
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
                            style: TextStyle(fontWeight: FontWeight.bold),
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
