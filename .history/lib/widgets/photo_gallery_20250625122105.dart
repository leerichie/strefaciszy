import 'package:flutter/material.dart';

typedef OnImagePicked = Future<String?> Function();

class PhotoGallery extends StatefulWidget {
  final List<String> imageUrls;
  final OnImagePicked onAddImage;
  final ValueChanged<int> onDelete; // index of image to delete

  const PhotoGallery({
    Key? key,
    required this.imageUrls,
    required this.onAddImage,
    required this.onDelete,
  }) : super(key: key);

  @override
  _PhotoGalleryState createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  // Which index is currently expanded? -1 = none.
  int _expanded = -1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _expanded >= 0 ? 300 : 88,
      child: Column(
        children: [
          // Row of thumbnails + add button
          SizedBox(
            height: 88,
            child: Row(
              children: [
                // Add button (unchanged)
                GestureDetector(
                  onTap: () async {
                    final url = await widget.onAddImage();
                    if (url != null) setState(() {});
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Icon(Icons.add_a_photo)),
                  ),
                ),

                // Thumbnails
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.imageUrls.length,
                    itemBuilder: (ctx, i) {
                      final url = widget.imageUrls[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Stack(
                          children: [
                            // Thumbnail
                            GestureDetector(
                              onTap: () => setState(() {
                                _expanded = (_expanded == i) ? -1 : i;
                              }),
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

                            // Delete button
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

          // Expanded preview
          if (_expanded >= 0)
            Expanded(
              child: Center(
                child: Image.network(
                  widget.imageUrls[_expanded],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 64),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
