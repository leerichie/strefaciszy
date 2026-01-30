// screens/archives_screen.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key});

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // clear screen of unarchived
  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream {
    return FirebaseFirestore.instance
        .collectionGroup('archives')
        .where('isActive', isEqualTo: true)
        .orderBy('archivedAt', descending: true)
        .snapshots();
  }

  Future<void> _openArchive({
    required String downloadUrl,
    required String filePath,
  }) async {
    try {
      String url = downloadUrl.trim();

      if (url.isEmpty) {
        final path = filePath.trim();
        if (path.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Brak linku i brak ścieżki pliku')),
          );
          return;
        }

        url = await FirebaseStorage.instance.ref(path).getDownloadURL();
      }

      final uri = Uri.tryParse(url);
      if (uri == null) throw 'Nieprawidłowy URL: $url';

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw 'launchUrl() returned false';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nie można otworzyć pliku: $e')));
    }
  }

  String _fmtTs(dynamic ts) {
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      dt = DateTime.tryParse(ts?.toString() ?? '') ?? DateTime(2000);
    }
    return DateFormat('dd.MM.yyyy • HH:mm', 'pl_PL').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    debugPrint('AUTH currentUser = ${u?.uid}  email=${u?.email}');

    return AppScaffold(
      title: 'Archive',
      showBackOnWeb: true,
      centreTitle: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DismissKeyboard(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Szukaj (klient / projekt)...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _filter = v.trim()),
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Resetuj'),
                    onPressed: () {
                      setState(() => _filter = '');
                      _searchCtrl.clear();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Błąd: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs
                    .where((d) => d.id == 'current')
                    .toList();

                final filtered = docs.where((d) {
                  final m = d.data();

                  final cust = (m['customerName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final proj = (m['projectName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final f = _filter.toLowerCase();

                  if (f.isEmpty) return true;
                  return cust.contains(f) || proj.contains(f);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Brak archives.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    final m = doc.data();

                    final customerName =
                        (m['customerName'] as String?)?.trim().isNotEmpty ==
                            true
                        ? (m['customerName'] as String).trim()
                        : '–';
                    final projectName =
                        (m['projectName'] as String?)?.trim().isNotEmpty == true
                        ? (m['projectName'] as String).trim()
                        : '–';

                    final when = _fmtTs(m['archivedAt']);
                    final url = (m['downloadUrl'] ?? '').toString();
                    final filePath = (m['filePath'] ?? '').toString();
                    final canDownload =
                        url.trim().isNotEmpty || filePath.trim().isNotEmpty;

                    return ListTile(
                      dense: true,
                      title: Row(
                        children: [
                          const Icon(Icons.archive, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AutoSizeText(
                              '$customerName\n$projectName',
                              maxLines: 2,
                              minFontSize: 10,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          when,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),

                      trailing: IconButton(
                        icon: Icon(
                          Icons.download,
                          color: canDownload ? Colors.blue : Colors.grey,
                        ),
                        tooltip: canDownload
                            ? 'Pobierz / Otwieraj'
                            : 'Brak linku',
                        onPressed: canDownload
                            ? () => _openArchive(
                                downloadUrl: url,
                                filePath: filePath,
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
