import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/widgets/note_dialogue.dart';

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
    // sort newest first
    final sorted = List<Note>.from(notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // Add button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () async => await onAddNote(context),
              child: Container(
                width: 44,
                height: 44,
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
            child: sorted.isEmpty
                ? const Center(
                    child: Text('Brak', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: sorted.length,
                    itemBuilder: (ctx, i) {
                      final note = sorted[i];
                      final header = note.userName;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Stack(
                          children: [
                            InkWell(
                              onTap: () async {
                                final updated = await showNoteDialog(
                                  context,
                                  userName: note.userName,
                                  createdAt: note.createdAt,
                                  initial: note.text,
                                );
                                if (updated != null &&
                                    updated.trim() != note.text) {
                                  await onEdit(i, updated.trim());
                                }
                              },
                              child: Container(
                                width: 64,
                                height: 44,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: AutoSizeText(
                                  header,
                                  maxLines: 2,
                                  minFontSize: 8,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
