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
    // Always show newest note preview first
    final latest = notes.isNotEmpty ? notes.first : null;
    final snippet = latest != null
        ? (latest.text.length > 50
              ? '${latest.text.substring(0, 50)}…'
              : latest.text)
        : null;

    return SizedBox(
      height: 88,
      child: Row(
        children: [
          // Add-note icon
          InkWell(
            onTap: () async {
              final note = await onAddNote(context);
              // parent will refresh notes via Firestore stream
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

          // Preview of the newest note or placeholder
          Expanded(
            child: snippet == null
                ? const Center(
                    child: Text(
                      'Brak notatek',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Stack(
                    children: [
                      InkWell(
                        onTap: () {
                          // Show full note in dialog
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(
                                '${latest!.userName} • '
                                '${DateFormat('dd.MM.yyyy').format(latest.createdAt)}',
                              ),
                              content: Text(latest.text),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          height: 64,
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

                      // Delete newest note
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => onDelete(0),
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
          ),
        ],
      ),
    );
  }
}
