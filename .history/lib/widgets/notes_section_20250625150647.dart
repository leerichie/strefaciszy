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
    super.key,
    required this.notes,
    required this.onAddNote,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure newest-first order
    final sorted = List<Note>.from(notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Remove duplicates (by timestamp + text)
    final seen = <String>{};
    final unique = <Note>[];
    for (var note in sorted) {
      final key = '${note.createdAt.toIso8601String()}|${note.text}';
      if (seen.add(key)) unique.add(note);
    }

    return SizedBox(
      height: 100,
      child: Row(
        children: [
          // Add-note box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () async => await onAddNote(context),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(child: Icon(Icons.note_add, size: 32)),
              ),
            ),
          ),

          // Thumbnails for notes
          Expanded(
            child: unique.isEmpty
                ? const Center(
                    child: Text(
                      'Brak notatek',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: unique.length,
                    itemBuilder: (ctx, i) {
                      final note = unique[i];
                      final snippet = note.text.length > 30
                          ? '${note.text.substring(0, 30)}…'
                          : note.text;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Stack(
                          children: [
                            InkWell(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(
                                    '${note.userName} • ${DateFormat('dd.MM.yyyy').format(note.createdAt)}',
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
                              ),
                              child: Container(
                                width: 120,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  snippet,
                                  maxLines: 3,
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
