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

class _AppPalette {
  static const bodyFont = 'Bose (Regular)';
  static const headlineFont = 'Bose-Headline (Bold)';
  static const surface = Colors.white;
  static const bg = Color(0xFFF4F6F7);
  static const line = Color(0xFFD4DCE0);
  static const text = Color(0xFF1E2B2F);
  static const muted = Color(0xFF607176);
  static const brand = Color(0xFF2574A9);
  static const danger = Color(0xFFE04747);
}

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
                      decoration: InputDecoration(
                        labelText: 'Szukaj (klient / projekt)...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _AppPalette.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _AppPalette.brand, width: 1.5),
                        ),
                        labelStyle: const TextStyle(fontFamily: _AppPalette.bodyFont, color: _AppPalette.muted),
                        hintStyle: const TextStyle(fontFamily: _AppPalette.bodyFont, color: _AppPalette.muted),
                      ),
                      onChanged: (v) => setState(() => _filter = v.trim()),
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: _AppPalette.brand),
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
          const Divider(height: 1, color: _AppPalette.line, thickness: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Błąd: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _AppPalette.brand));
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
                  separatorBuilder: (_, __) => const Divider(height: 1, color: _AppPalette.line, thickness: 1),
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontFamily: _AppPalette.bodyFont,
                                color: _AppPalette.text,
                                fontWeight: FontWeight.w600,
                              ),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: _AppPalette.bodyFont,
                            color: _AppPalette.muted,
                          ),
                        ),
                      ),

                      trailing: IconButton(
                        icon: Icon(
                          Icons.download,
                          color: canDownload ? _AppPalette.brand : _AppPalette.line,
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
