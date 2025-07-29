import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
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
    // sort newest
    final sorted = List<Note>.from(notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return GestureDetector(
      onTap: () async => await onAddNote(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 70,
        child: sorted.isEmpty
            ? Center(
                child: Text(
                  'Dotknij aby dodać notatka',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sorted.length + 1,
                itemBuilder: (ctx, i) {
                  if (i < sorted.length) {
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
                              height: 70,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AutoSizeText(
                                header,
                                maxLines: 2,
                                minFontSize: 10,
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
                  }
                  // trailing placeholder
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () async => await onAddNote(context),
                      child: Container(
                        width: 80,
                        height: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Dotknij aby dodać notatka',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
