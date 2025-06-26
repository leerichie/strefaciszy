import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef OnImagePicked = Future<String?> Function(ImageSource source);
typedef OnImageDeleted = Future<void> Function(int index);

class PhotoGallery extends StatelessWidget {
  final List<String> imageUrls;
  final OnImagePicked onAddImage;
  final OnImageDeleted onDelete;

  const PhotoGallery({
    super.key,
    required this.imageUrls,
    required this.onAddImage,
    required this.onDelete,
  });

  void _showPickOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Zrób fota'),
              onTap: () async {
                Navigator.pop(context);
                onAddImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Wybierz z galerii'),
              onTap: () async {
                Navigator.pop(context);
                onAddImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) {
          return _ImageViewer(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
            onDelete: onDelete,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => _showPickOptions(context),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(child: Icon(Icons.add_a_photo, size: 32)),
              ),
            ),
          ),

          // Thumbnails
          Expanded(
            child: imageUrls.isEmpty
                ? const Center(
                    child: Text(
                      'Brak fotek',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    itemBuilder: (_, i) {
                      final url = imageUrls[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Stack(
                          children: [
                            InkWell(
                              onTap: () => _openViewer(context, i),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  url,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey,
                                    width: 54,
                                    height: 54,
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
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final OnImageDeleted onDelete;

  const _ImageViewer({
    required this.imageUrls,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  __ImageViewerState createState() => __ImageViewerState();
}

class __ImageViewerState extends State<_ImageViewer> {
  late PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // tap outside dismiss
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: widget.imageUrls.length,
                itemBuilder: (ctx, i) {
                  return Center(
                    child: Image.network(
                      widget.imageUrls[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        size: 54,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              // delete full-screen
              Positioned(
                top: 16,
                right: 16,
                child: InkWell(
                  onTap: () {
                    widget.onDelete(_current);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // page indicator
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${_current + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
