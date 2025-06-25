// lib/widgets/notes_section.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef OnNoteAdded = Future<Note?> Function(BuildContext context);
typedef OnNoteDeleted = Future<void> Function(int index);

class Note {
  final String text;
  final String userName;
  final DateTime createdAt;

  Note({required this.text, required this.userName, required this.createdAt});
}

class NotesSection extends StatelessWidget {
  final List<Note> notes;
  final OnNoteAdded onAddNote;
  final OnNoteDeleted onDelete;

  const NotesSection({
    Key? key,
    required this.notes,
    required this.onAddNote,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              final note = await onAddNote(context);
              if (note != null) {
                // parent updates its state
              }
            },
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.note_add),
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? const Center(
                    child: Text(
                      'Brak notatek',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: notes.length,
                    itemBuilder: (ctx, i) {
                      final note = notes[i];
                      final snippet = note.text.length > 30
                          ? '${note.text.substring(0, 30)}…'
                          : note.text;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Stack(
                          children: [
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(
                                      '${note.userName} • '
                                      '${DateFormat('dd.MM.yyyy').format(note.createdAt)}',
                                    ),
                                    content: Text(note.text),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                width: 120,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  snippet,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () => onDelete(i),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
