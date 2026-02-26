import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TagPickerSheet extends StatefulWidget {
  final bool compact;
  final String query;
  final ValueChanged<Map<String, dynamic>>? onPick;

  const TagPickerSheet({
    super.key,
    this.compact = false,
    this.query = '',
    this.onPick,
  });

  @override
  State<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<TagPickerSheet> {
  String _q = '';

  @override
  void initState() {
    super.initState();
    _q = widget.query.trim().toLowerCase();
  }

  @override
  void didUpdateWidget(covariant TagPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _q = widget.query.trim().toLowerCase();
    }
  }

  String _toToken(String label) {
    final s = label.trim();
    if (s.isEmpty) return '';
    final token = s
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\w\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return token;
  }

  bool _match(String text) {
    if (_q.isEmpty) return true;
    return text.toLowerCase().contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      height: widget.compact ? 260 : 520,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 0, bottom: 0),
        child: Column(
          children: [
            // Row(
            //   children: [
            //     const Text(
            //       'Wybierz #',
            //       style: TextStyle(fontWeight: FontWeight.w600),
            //     ),
            //     const Spacer(),
            //     IconButton(
            //       icon: const Icon(Icons.close),
            //       onPressed: () => Navigator.pop(context),
            //       tooltip: 'Zamknij',
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  const _SectionHeader('Projekty'),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collectionGroup('projects')
                        .orderBy('title')
                        .limit(250)
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      final items = docs
                          .map((d) {
                            final data = d.data();
                            final title =
                                (data['title'] as String?)?.trim() ?? '';
                            final customerId =
                                d.reference.parent.parent?.id ?? '';
                            return {
                              'projectId': d.id,
                              'customerId': customerId,
                              'title': title,
                            };
                          })
                          .where((x) => (x['title'] as String).isNotEmpty)
                          .where((x) => _match(x['title'] as String))
                          .take(30)
                          .toList();

                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(left: 8, top: 6, bottom: 10),
                          child: Text('Brak wyników.'),
                        );
                      }

                      return Column(
                        children: items.map((p) {
                          final title = p['title'] as String;
                          final token = _toToken(title);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.apartment_outlined),
                            title: Text(title),
                            subtitle: token.isEmpty ? null : Text('#$token'),
                            onTap: () {
                              final picked = <String, dynamic>{
                                'type': 'project',
                                'customerId': p['customerId'],
                                'projectId': p['projectId'],
                                'label': title,
                                'token': token,
                              };
                              if (widget.onPick != null) {
                                widget.onPick!(picked);
                              } else {
                                Navigator.pop(context, picked);
                              }
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const _SectionHeader('Klienci'),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('customers')
                        .orderBy('name')
                        .limit(200)
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      final items = docs
                          .map((d) {
                            final name =
                                (d.data()['name'] as String?)?.trim() ?? '';
                            return {'id': d.id, 'label': name};
                          })
                          .where((x) => (x['label'] as String).isNotEmpty)
                          .where((x) => _match(x['label'] as String))
                          .take(30)
                          .toList();

                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(left: 8, top: 6, bottom: 10),
                          child: Text('Brak wyników.'),
                        );
                      }

                      return Column(
                        children: items.map((c) {
                          final label = c['label'] as String;
                          final token = _toToken(label);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_pin_rounded),
                            title: Text(label),
                            subtitle: token.isEmpty ? null : Text('#$token'),
                            onTap: () {
                              final picked = <String, dynamic>{
                                'type': 'client',
                                'id': c['id'],
                                'label': label,
                                'token': token,
                              };
                              if (widget.onPick != null) {
                                widget.onPick!(picked);
                              } else {
                                Navigator.pop(context, picked);
                              }
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.compact) return content;

    return SafeArea(
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: content,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 8, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
