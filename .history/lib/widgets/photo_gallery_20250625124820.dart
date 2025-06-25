// lib/widgets/photo_gallery.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef OnImagePicked = Future<String?> Function(ImageSource source);
typedef OnImageDeleted = Future<void> Function(int index);

class PhotoGallery extends StatelessWidget {
  final List<String> imageUrls;
  final OnImagePicked onAddImage;
  final OnImageDeleted onDelete;

  const PhotoGallery({
    Key? key,
    required this.imageUrls,
    required this.onAddImage,
    required this.onDelete,
  }) : super(key: key);

  void _showPickOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Zrob fota'),
              onTap: () {
                Navigator.pop(context);
                onAddImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Wybieraj...'),
              onTap: () {
                Navigator.pop(context);
                onAddImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          InkWell(
            onTap: () => _showPickOptions(context),
            child: Container(
              width: 64,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(child: Icon(Icons.add_a_photo, size: 32)),
            ),
          ),

          // Thumbnails row
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (_, i) {
                final url = imageUrls[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Stack(
                    children: [
                      // Thumbnail + tap-to-preview
                      InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 64),
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            url,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey,
                              width: 64,
                              height: 64,
                            ),
                          ),
                        ),
                      ),

                      // Delete “×” button
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
