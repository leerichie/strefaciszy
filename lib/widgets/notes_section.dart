// lib/widgets/notes_section.dart

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
  final bool readOnly;

  const NotesSection({
    super.key,
    required this.notes,
    required this.onAddNote,
    required this.onEdit,
    required this.onDelete,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Note>.from(notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    const double tileHeight = 70;
    const double addButtonSize = 22.0;

    if (sorted.isEmpty) {
      return SizedBox(
        height: tileHeight,
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                onTap: readOnly ? null : () async => await onAddNote(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: addButtonSize, color: Colors.black),
                    const SizedBox(width: 6),
                    Text(
                      'Dodaj RAPORT',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            if (!readOnly)
              Positioned(
                top: 4,
                right: 4,
                child: _AddNoteButton(
                  size: addButtonSize,
                  onTap: () async => await onAddNote(context),
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      height: tileHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.only(right: 36.0),
                child: Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    // 🔴 OLD (buggy):
                    // for (int i = 0; i < sorted.length; i++)
                    //   _NoteTile(
                    //     note: sorted[i],
                    //     index: i,
                    //     ...
                    for (final note in sorted)
                      _NoteTile(
                        note: note,
                        index: notes.indexOf(note),
                        onEdit: onEdit,
                        onDelete: onDelete,
                        readOnly: readOnly,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // "+"
          if (!readOnly)
            Positioned(
              top: 4,
              right: 4,
              child: _AddNoteButton(
                size: addButtonSize,
                onTap: () async => await onAddNote(context),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showNoteReadOnlyDialog(
  BuildContext context, {
  required String userName,
  required DateTime createdAt,
  required String text,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(userName),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Zamknij'),
        ),
      ],
    ),
  );
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final int index;
  final OnNoteEdited onEdit;
  final OnNoteDeleted onDelete;

  final bool readOnly;

  const _NoteTile({
    required this.note,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final header = note.userName;

    return SizedBox(
      width: 64,
      height: 70,
      child: Stack(
        children: [
          InkWell(
            onTap: () async {
              if (readOnly) {
                await showNoteReadOnlyDialog(
                  context,
                  userName: note.userName,
                  createdAt: note.createdAt,
                  text: note.text,
                );
                return;
              }

              final updated = await showNoteDialog(
                context,
                userName: note.userName,
                createdAt: note.createdAt,
                initial: note.text,
              );
              if (updated != null && updated.trim() != note.text) {
                await onEdit(index, updated.trim());
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: AutoSizeText(
                header,
                maxLines: 2,
                minFontSize: 10,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (!readOnly)
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: () => onDelete(index),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddNoteButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _AddNoteButton({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size + 6,
        height: size + 6,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add, size: size, color: Colors.grey[800]),
      ),
    );
  }
}
