// screens/_user_picker_sheet.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserPickerSheet extends StatefulWidget {
  final bool compact;
  final bool showSearch;
  final String query;
  final ValueChanged<Map<String, dynamic>>? onPick;

  const UserPickerSheet({
    super.key,
    this.compact = false,
    this.showSearch = true,
    this.query = '',
    this.onPick,
  });

  @override
  State<UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<UserPickerSheet> {
  String _q = '';

  @override
  void initState() {
    super.initState();
    _q = widget.query.trim().toLowerCase();
  }

  @override
  void didUpdateWidget(covariant UserPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.showSearch != widget.showSearch) {
      _q = widget.query.trim().toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    final content = SizedBox(
      height: widget.compact ? 260 : 460,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Wybierz użytkownika',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Zamknij',
                ),
              ],
            ),
            if (widget.showSearch) ...[
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Wpisz imię...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];
                  final items =
                      docs
                          .map((d) {
                            final name =
                                (d.data()['name'] as String?)?.trim() ?? '';
                            final first = name.isNotEmpty
                                ? name.split(' ').first
                                : 'Użytkownik';
                            return {
                              'uid': d.id,
                              'display': first,
                              'full': name,
                            };
                          })
                          .where((u) => (u['uid'] as String) != myUid)
                          .where((u) {
                            final q = widget.showSearch
                                ? _q
                                : widget.query.trim().toLowerCase();
                            if (q.isEmpty) return true;

                            final full = (u['full'] as String).toLowerCase();
                            final disp = (u['display'] as String).toLowerCase();
                            return full.contains(q) || disp.contains(q);
                          })
                          .toList()
                        ..sort(
                          (a, b) => (a['full'] as String).compareTo(
                            b['full'] as String,
                          ),
                        );

                  if (items.isEmpty) {
                    return const Center(child: Text('Brak wyników.'));
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final u = items[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person),
                        title: Text(u['full'] as String),
                        onTap: () {
                          final picked = {
                            'uid': u['uid'],
                            'display': u['display'],
                          };

                          if (widget.onPick != null) {
                            widget.onPick!(picked);
                          } else {
                            Navigator.pop(context, picked);
                          }
                        },
                      );
                    },
                  );
                },
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
