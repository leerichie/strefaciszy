// lib/widgets/notes_section.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Note {
  final String text;
  final String userName;
  final DateTime createdAt;

  Note({required this.text, required this.userName, required this.createdAt});
}

typedef OnNoteAdded = Future<Note?> Function(BuildContext context);

class NotesSection extends StatefulWidget {
  final List<Note> notes;
  final OnNoteAdded onAddNote;
  final ValueChanged<int> onDelete; // index of note to delete

  const NotesSection({
    Key? key,
    required this.notes,
    required this.onAddNote,
    required this.onDelete,
  }) : super(key: key);

  @override
  _NotesSectionState createState() => _NotesSectionState();
}

class _NotesSectionState extends State<NotesSection> {
  int _expanded = -1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88 + (_expanded >= 0 ? 100 : 0),
      child: Column(
        children: [
          // Row of add-note + snippets
          SizedBox(
            height: 88,
            child: Row(
              children: [
                // Add‐note button
                GestureDetector(
                  onTap: () async {
                    final newNote = await widget.onAddNote(context);
                    if (newNote != null) setState(() {});
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Icon(Icons.note_add, size: 32)),
                  ),
                ),

                // Snippets
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.notes.length,
                    itemBuilder: (ctx, i) {
                      final note = widget.notes[i];
                      final snippet = note.text.length > 30
                          ? '${note.text.substring(0, 30)}…'
                          : note.text;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Stack(
                          children: [
                            // snippet card
                            GestureDetector(
                              onTap: () => setState(() {
                                _expanded = (_expanded == i) ? -1 : i;
                              }),
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

                            // delete button
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => widget.onDelete(i),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
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
          ),

          // Expanded note
          if (_expanded >= 0)
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(widget.notes[_expanded].text),
            ),
        ],
      ),
    );
  }
}
