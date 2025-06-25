class NotesSection extends StatelessWidget {
  final List<Note> notes;
  final OnNoteAdded onAddNote;

  const NotesSection({Key? key, required this.notes, required this.onAddNote})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88, // same height as PhotoGallery
      child: Row(
        children: [
          // “Add Note” button, mimicking your photo add style:
          GestureDetector(
            onTap: () async {
              final newNote = await onAddNote(context);
              if (newNote != null) {
                // parent handles inserting into state/firestore
              }
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

          // Horizontal scroll of note previews:
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: notes.length,
              itemBuilder: (ctx, i) {
                final note = notes[i];
                // Simple text preview: first 2 lines or 30 chars
                final snippet = note.text.length > 30
                    ? '${note.text.substring(0, 30)}…'
                    : note.text;
                return GestureDetector(
                  onTap: () {
                    // Show full note in a dialog
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(
                          '${note.userName} • ${DateFormat('dd.MM.yyyy').format(note.createdAt)}',
                        ),
                        content: Text(note.text),
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
                    width: 120,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
