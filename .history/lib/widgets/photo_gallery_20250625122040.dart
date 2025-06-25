import 'package:flutter/material.dart';

typedef OnImagePicked = Future<String?> Function();
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        children: [
          // Add button
          InkWell(
            onTap: () async {
              final url = await onAddImage();
              // parent updates list and calls setState
            },
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add_a_photo),
            ),
          ),

          // Thumbnails
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (ctx, i) {
                final url = imageUrls[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Stack(
                    children: [
                      // thumbnail
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 64),
                              ),
                            ),
                          );
                        },
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

                      // delete “×”
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
