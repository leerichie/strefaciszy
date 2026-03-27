// screens/projects_list_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

import 'project_editor_screen.dart';

enum _ProjectSort { newest, oldest, updated, nameAZ, nameZA }

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
  Set<String> _favProjectIds = {};
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _favsSub;
  Map<String, DateTime?> _todoSeenAtByProject = {};
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _todoSeenSub;

  _ProjectSort _sort = _ProjectSort.updated;

  @override
  void initState() {
    super.initState();
    _customersFuture = _loadCustomers();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    _favsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favouriteProjects')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() {
            _favProjectIds = snap.docs.map((d) => d.id).toSet();
          });
        });
    _todoSeenSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('projectTodoSeen')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() {
            _todoSeenAtByProject = {
              for (final d in snap.docs)
                d.id: (d.data()['seenAt'] as Timestamp?)?.toDate(),
            };
          });
        });
  }

  Future<Map<String, String>> _loadCustomers() async {
    final snap = await FirebaseFirestore.instance.collection('customers').get();
    return {
      for (final d in snap.docs)
        d.id: (d.data()['name'] as String?) ?? 'Nieznany klient',
    };
  }

  Future<void> _toggleFavouriteProject(
    String projectId,
    String title,
    String customerId,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final favDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favouriteProjects')
        .doc(projectId);

    if (_favProjectIds.contains(projectId)) {
      await favDoc.delete();
    } else {
      await favDoc.set({'title': title, 'customerId': customerId});
    }
  }

  DateTime _entryMoment(Map<String, dynamic> e) {
    final updated = e['updatedAt'];
    if (updated is Timestamp) return updated.toDate();

    final created = e['createdAt'];
    if (created is Timestamp) return created.toDate();

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, int> _todoBadgeCounts({
    required Map<String, dynamic> projectData,
    required DateTime? seenAt,
  }) {
    final raw = (projectData['currentChangesNotes'] as List?) ?? const [];

    int red = 0;
    int blue = 0;
    int black = 0;

    for (final item in raw) {
      if (item is! Map) continue;

      final e = Map<String, dynamic>.from(item);
      final isTask = e['isTask'] == true;
      final done = e['done'] == true;

      if (!isTask || done) continue;

      final when = _entryMoment(e);
      if (seenAt != null && !when.isAfter(seenAt)) continue;

      final color = (e['color'] ?? 'black').toString();
      if (color == 'red') {
        red++;
      } else if (color == 'blue') {
        blue++;
      } else {
        black++;
      }
    }

    return {'red': red, 'blue': blue, 'black': black};
  }

  Widget _todoBadges(Map<String, int> counts) {
    Widget badge(Color color, int count) {
      return Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(minWidth: 20),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final children = <Widget>[];
    if ((counts['red'] ?? 0) > 0) {
      children.add(badge(Colors.red, counts['red']!));
    }
    if ((counts['blue'] ?? 0) > 0) {
      children.add(badge(Colors.blue, counts['blue']!));
    }
    if ((counts['black'] ?? 0) > 0) {
      children.add(badge(Colors.black87, counts['black']!));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  @override
  void dispose() {
    _favsSub.cancel();
    _todoSeenSub.cancel();
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
                  PopupMenuItem(
                    value: _ProjectSort.updated,
                    child: Text('Zmiany'),
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

              final projects = docs
                  .map((d) {
                    final data = d.data();
                    final title = (data['title'] as String?) ?? '';
                    final createdAt = (data['createdAt'] as Timestamp?)
                        ?.toDate();
                    final updatedAt = (data['updatedAt'] as Timestamp?)
                        ?.toDate();
                    final customerId = d.reference.parent.parent?.id ?? '';

                    final archived = data['archived'] == true;

                    return _ProjectItem(
                      id: d.id,
                      title: title,
                      customerId: customerId,
                      createdAt: createdAt,
                      updatedAt: updatedAt,
                      archived: archived,
                      data: data,
                    );
                  })
                  .where((p) {
                    if (p.archived) return false;

                    if (_search.isEmpty) return true;
                    return p.title.toLowerCase().contains(_search);
                  })
                  .toList();

              if (projects.isEmpty) {
                return const Center(child: Text('Brak projektów.'));
              }

              final Map<String, List<_ProjectItem>> grouped = {};
              for (final p in projects) {
                grouped.putIfAbsent(p.customerId, () => []).add(p);
              }

              final epoch = DateTime.fromMillisecondsSinceEpoch(0);

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

              DateTime effectiveDate(_ProjectItem p) =>
                  (p.updatedAt ?? p.createdAt ?? epoch);

              DateTime newestUpdateOf(List<_ProjectItem> items) => items
                  .map(effectiveDate)
                  .fold(epoch, (prev, d) => d.isAfter(prev) ? d : prev);

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
                    case _ProjectSort.updated:
                      return newestUpdateOf(
                        b.value,
                      ).compareTo(newestUpdateOf(a.value));
                  }
                });

              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (ctx, index) {
                  final entry = entries[index];
                  final customerId = entry.key;
                  final customerName =
                      customerNames[customerId] ?? 'Nieznany klient';

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
                        case _ProjectSort.updated:
                          return effectiveDate(b).compareTo(effectiveDate(a));
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
                        final dateSource = p.updatedAt ?? p.createdAt;
                        final dateText = dateSource != null
                            ? dateFmt.format(dateSource)
                            : null;

                        final isArchived = p.archived;
                        final isFav = _favProjectIds.contains(p.id);

                        final counts = _todoBadgeCounts(
                          projectData: p.data,
                          seenAt: _todoSeenAtByProject[p.id],
                        );

                        final hasBadges =
                            (counts['red'] ?? 0) > 0 ||
                            (counts['blue'] ?? 0) > 0 ||
                            (counts['black'] ?? 0) > 0;

                        return ListTile(
                          dense: false,
                          title: Text(
                            p.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isArchived ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dateText != null)
                                Row(
                                  children: [
                                    Text(
                                      isArchived
                                          ? '$dateText • ARCHIWUM'
                                          : dateText,
                                      style: TextStyle(
                                        color: isArchived ? Colors.grey : null,
                                      ),
                                    ),
                                    if (hasBadges) ...[
                                      const SizedBox(width: 6),
                                      _todoBadges(counts),
                                    ],
                                  ],
                                )
                              else if (isArchived)
                                const Text(
                                  'ARCHIWUM',
                                  style: TextStyle(color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: isArchived
                              ? const Icon(Icons.archive, color: Colors.grey)
                              : IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                  ),
                                  tooltip: isFav
                                      ? 'Usuń z ulubionych'
                                      : 'Dodaj do ulubionych',
                                  onPressed: () => _toggleFavouriteProject(
                                    p.id,
                                    p.title,
                                    p.customerId,
                                  ),
                                ),
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
  final DateTime? updatedAt;
  final bool archived;
  final Map<String, dynamic> data;

  _ProjectItem({
    required this.id,
    required this.title,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    required this.archived,
    required this.data,
  });
}
