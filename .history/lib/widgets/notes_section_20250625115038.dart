import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef OnImagePicked = Future<String?> Function();

class PhotoGallery extends StatelessWidget {
  /// A list of image URLs to display.
  final List<String> imageUrls;

  /// Called when the “+” button is tapped. Should pick/upload an image
  /// and return its download URL (or null on cancel/fail).
  final OnImagePicked onAddImage;

  const PhotoGallery({
    super.key,
    required this.imageUrls,
    required this.onAddImage,
  });

 @override
Widget build(BuildContext context) {
  return SizedBox(
    height: 88, // same as your PhotoGallery height
    child: Row(
      children: [
        // “Add note” button exactly like your add-photo button
        GestureDetector(
          onTap: () async {
            final newNote = await onAddNote(context);
            if (newNote != null) {
              // parent already inserts into Firestore + local _notes
            }
          },
          child: Container(
            width: 64,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.note_add, size: 32),
            ),
          ),
        ),

        // Horizontal scroller of note previews
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: notes.length,
            itemBuilder: (ctx, i) {
              final note = notes[i];
              final snippet = note.text.length > 30
                  ? note.text.substring(0, 30) + '…'
                  : note.text;
              return GestureDetector(
                onTap: () {
                  // Show full note
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
                        )
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
