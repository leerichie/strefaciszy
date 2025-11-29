// lib/screens/project_image_gallery_screen.dart
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_drawer.dart';

class ProjectImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final Future<void> Function(String url) onDelete;

  const ProjectImageGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<ProjectImageGalleryScreen> createState() =>
      _ProjectImageGalleryScreenState();
}

class _ProjectImageGalleryScreenState extends State<ProjectImageGalleryScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 20,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final url = widget.images[_currentIndex];
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Usuń fota?'),
                  content: const Text('Na pewno chcesz usunąć to zdjęcie?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Anuluj'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Usuń'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;

              await widget.onDelete(url);
              widget.images.removeAt(_currentIndex);
              if (widget.images.isEmpty) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                return;
              }
              setState(() {
                if (_currentIndex >= widget.images.length) {
                  _currentIndex = widget.images.length - 1;
                  _pageController.jumpToPage(_currentIndex);
                }
              });
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: Image.network(widget.images[i])),
        ),
      ),
    );
  }
}
