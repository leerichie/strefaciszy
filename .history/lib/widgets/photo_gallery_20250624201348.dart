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
    Key? key,
    required this.imageUrls,
    required this.onAddImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          // “Add” button
          GestureDetector(
            onTap: () async {
              final url = await onAddImage();
              if (url != null) {
                // parent should insert into its state / Firestore
              }
            },
            child: Container(
              width: 64,
              margin: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(Icons.add_a_photo)),
            ),
          ),

          // Thumbnails list
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (ctx, i) {
                final url = imageUrls[i];
                return GestureDetector(
                  onTap: () {
                    // open full‐screen preview
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: Image.network(url, fit: BoxFit.contain),
                      ),
                    );
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      image: DecorationImage(
                        image: NetworkImage(url),
                        fit: BoxFit.cover,
                      ),
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
