import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef OnNoteAdded = Future<Note?> Function(BuildContext context);
typedef OnNoteEdited = Future<void> Function(int index, String newText);
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
  final OnNoteEdited onEdit;
  final OnNoteDeleted onDelete;

  const NotesSection({
    super.key,
    required this.notes,
    required this.onAddNote,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Note>.from(notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Dedupe
    final seenTexts = <String>{};
    final unique = <Note>[];
    for (var note in sorted) {
      if (seenTexts.add(note.text)) unique.add(note);
    }

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          // Add
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () async => await onAddNote(context),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(child: Icon(Icons.note_add, size: 32)),
              ),
            ),
          ),

          // Note thumbnails
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
                              onTap: () async {
                                final controller = TextEditingController(
                                  text: note.text,
                                );
                                await showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note.userName.isNotEmpty
                                              ? note.userName
                                              : 'Unknown',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat(
                                            'dd.MM.yyyy',
                                          ).format(note.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: TextField(
                                      controller: controller,
                                      maxLines: null,
                                      decoration: const InputDecoration(
                                        hintText: 'Edytuj',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Anuluj'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          onEdit(i, controller.text.trim());
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Zapisz'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                width: 54,
                                height: 54,
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
