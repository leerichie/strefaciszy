// lib/widgets/project_images_section.dart
import 'dart:io' as io;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:strefa_ciszy/services/project_files_service.dart';
import 'package:strefa_ciszy/widgets/project_filter_row.dart';

enum _ImageSort { original, dateNewest, type }

class ProjectImagesSection extends StatefulWidget {
  final String customerId;
  final String projectId;
  final bool isAdmin;
  final List<Map<String, String>> initialFiles;

  const ProjectImagesSection({
    super.key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
    this.initialFiles = const [],
  });

  @override
  State<ProjectImagesSection> createState() => _ProjectImagesSectionState();
}

class _ProjectImagesSectionState extends State<ProjectImagesSection> {
  final List<Map<String, String>> _imageItems = [];

  bool _uploading = false;
  DropzoneViewController? _dropzoneController;
  bool _dropHighlight = false;
  bool _dragging = false;
  _ImageSort _sort = _ImageSort.original;
  bool _selectionMode = false;
  final Set<String> _selectedUrls = {};
  String _searchQuery = '';

  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
  };

  bool get _isDesktop {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    for (final f in widget.initialFiles) {
      _addIfImage(f);
    }
  }

  String _replaceExtension(String name, String newExt) {
    final dir = p.dirname(name);
    final base = p.basenameWithoutExtension(name);
    final file = '$base$newExt';
    return (dir == '.' || dir.isEmpty) ? file : p.join(dir, file);
  }

  Future<MapEntry<String, Uint8List>> _compressAndConvert(
    MapEntry<String, Uint8List> e,
  ) async {
    if (kIsWeb) return e;

    final name = e.key;
    final bytes = e.value;

    if (bytes.lengthInBytes < 120 * 1024) {
      final ext = p.extension(name).toLowerCase();
      if (ext == '.heic' || ext == '.heif') {
      } else {
        return e;
      }
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return e;

    const maxSide = 1280;

    img.Image resized;
    if (decoded.width >= decoded.height) {
      resized = img.copyResize(
        decoded,
        width: maxSide,
        height: (decoded.height * maxSide / decoded.width).round(),
      );
    } else {
      resized = img.copyResize(
        decoded,
        height: maxSide,
        width: (decoded.width * maxSide / decoded.height).round(),
      );
    }

    // jpg
    final jpgBytes = img.encodeJpg(resized, quality: 65);
    return MapEntry(
      _replaceExtension(name, '.jpg'),
      Uint8List.fromList(jpgBytes),
    );
  }

  bool _isImageName(String name) {
    final ext = p.extension(name).toLowerCase();
    if (kIsWeb && (ext == '.heic' || ext == '.heif')) return false;
    return _imageExtensions.contains(ext);
  }

  void _addIfImage(Map<String, String> item) {
    final bucket = (item['bucket'] ?? '').toLowerCase();

    if (bucket == 'files') return;
    if (bucket == 'images') {
      _imageItems.add(item);
      return;
    }

    final name = item['name'] ?? '';
    if (_isImageName(name)) {
      _imageItems.add(item);
    }
  }

  void _toggleSelection(String url) {
    setState(() {
      if (_selectedUrls.contains(url)) {
        _selectedUrls.remove(url);
      } else {
        _selectedUrls.add(url);
      }
    });
  }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _searchQuery);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Szukaj zdjęć'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nazwa / URL',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
            onSubmitted: (_) {
              Navigator.of(ctx).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Wyczyść'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Zamknij'),
            ),
          ],
        );
      },
    );
  }

  List<int> _getOrder(List<Map<String, String>> items) {
    final idxs = List<int>.generate(items.length, (i) => i);

    switch (_sort) {
      case _ImageSort.original:
        return idxs;

      case _ImageSort.dateNewest:
        // Newest = last added first
        idxs.sort((a, b) => b.compareTo(a));
        return idxs;

      case _ImageSort.type:
        idxs.sort((a, b) {
          final nameA = items[a]['name'] ?? '';
          final nameB = items[b]['name'] ?? '';
          final extA = p.extension(nameA).toLowerCase();
          final extB = p.extension(nameB).toLowerCase();
          final cmpExt = extA.compareTo(extB);
          if (cmpExt != 0) return cmpExt;
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });
        return idxs;
    }
  }

  Future<void> _clearImages() async {
    if (!widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tylko admin może skasować')),
      );
      return;
    }
    if (_imageItems.isEmpty) return;

    // If already in selection mode → delete selected
    if (_selectionMode) {
      if (_selectedUrls.isEmpty) {
        setState(() {
          _selectionMode = false;
        });
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Usuń zaznaczone fotek'),
          content: Text('Usunąć ${_selectedUrls.length} fotek?'),
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

      setState(() => _uploading = true);

      try {
        final copy = List<Map<String, String>>.from(_imageItems);
        for (final f in copy) {
          final url = f['url']!;
          if (!_selectedUrls.contains(url)) continue;

          await ProjectFilesService.deleteProjectFile(
            customerId: widget.customerId,
            projectId: widget.projectId,
            url: url,
            name: f['name']!,
          );
          _imageItems.remove(f);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zaznaczone fotek usunięte')),
          );
        }
      } catch (e) {
        debugPrint('Bulk delete selected images error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nie udało się skasować fotek')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _uploading = false;
            _selectionMode = false;
            _selectedUrls.clear();
          });
        }
      }

      return;
    }

    // First
    final choice = await showDialog<_ImageClearScope>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń fotek'),
        content: const Text('Co chcesz usunać?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ImageClearScope.select),
            child: const Text('Wybierz kilka'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _ImageClearScope.all),
            child: const Text('Wszystkie'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == _ImageClearScope.select) {
      setState(() {
        _selectionMode = true;
        _selectedUrls.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wybierz fotek do usunięcia, potem tap Skasuj'),
          ),
        );
      }
      return;
    }

    // ALL images
    setState(() => _uploading = true);

    try {
      final copy = List<Map<String, String>>.from(_imageItems);
      for (final f in copy) {
        await ProjectFilesService.deleteProjectFile(
          customerId: widget.customerId,
          projectId: widget.projectId,
          url: f['url']!,
          name: f['name']!,
        );
      }
      _imageItems.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wszystkie fotek usunięty')),
        );
      }
    } catch (e) {
      debugPrint('Bulk clear images error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się skasować fotek')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _moveImagesToFiles() async {
    if (!widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tylko admin może przenieść')),
      );
      return;
    }
    if (_imageItems.isEmpty) return;

    // first click => enter selection mode
    if (!_selectionMode) {
      setState(() {
        _selectionMode = true;
        _selectedUrls.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaznacz fotki, potem kliknij Przenieś')),
      );
      return;
    }

    // second click without selection => exit selection mode
    if (_selectedUrls.isEmpty) {
      setState(() => _selectionMode = false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Przenieś do Pliki'),
        content: Text('Przenieść ${_selectedUrls.length} elementów do Pliki?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Przenieś'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _uploading = true);

    try {
      for (final url in _selectedUrls) {
        await ProjectFilesService.setFileBucket(
          customerId: widget.customerId,
          projectId: widget.projectId,
          url: url,
          bucket: 'files',
        );
      }

      setState(() {
        _imageItems.removeWhere((f) => _selectedUrls.contains(f['url']));
        _selectionMode = false;
        _selectedUrls.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Przeniesiono do Pliki')));
      }
    } catch (e) {
      debugPrint('Move images -> files error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się przenieść')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _handleDesktopDropFiles(List<XFile> dropped) async {
    if (dropped.isEmpty) return;

    setState(() => _uploading = true);

    final entries = <MapEntry<String, Uint8List>>[];

    for (final xf in dropped) {
      try {
        final bytes = await xf.readAsBytes();
        entries.add(MapEntry(xf.name, bytes));
      } catch (e) {
        debugPrint('Failed to read dropped file "${xf.name}": $e');
      }
    }

    await _uploadEntries(entries);

    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _handleWebDropFiles(List<DropzoneFileInterface> files) async {
    if (!kIsWeb) return;
    if (_dropzoneController == null) {
      debugPrint('Dropzone controller is null');
      return;
    }
    if (files.isEmpty) return;

    setState(() => _uploading = true);

    try {
      final entries = <MapEntry<String, Uint8List>>[];

      for (final file in files) {
        try {
          final name = await _dropzoneController!.getFilename(file);
          final bytes = await _dropzoneController!.getFileData(file);
          entries.add(MapEntry(name, bytes));
        } catch (e) {
          debugPrint('Drop upload read error: $e');
        }
      }

      await _uploadEntries(entries);
    } catch (e) {
      debugPrint('Drop upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się wysłać pliku')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _takePhotoAndUpload() async {
    if (kIsWeb) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );

    if (picked == null) return;

    setState(() => _uploading = true);

    try {
      final bytes = await picked.readAsBytes();
      final name = picked.name.isNotEmpty
          ? picked.name
          : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _uploadEntries([MapEntry(name, bytes)]);
    } catch (e) {
      debugPrint('Camera capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się zrobić zdjęcia')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _handleAddPressed() async {
    if (kIsWeb || _isDesktop) {
      await _pickAndUploadFiles();
      return;
    }

    final platform = defaultTargetPlatform;
    final isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    if (!isMobile) {
      await _pickAndUploadFiles();
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Zrób fotka'),
                onTap: () => Navigator.of(ctx).pop('camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Z galerii'),
                onTap: () => Navigator.of(ctx).pop('gallery'),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Anuluj'),
                onTap: () => Navigator.of(ctx).pop('cancel'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null || choice == 'cancel') return;

    if (choice == 'camera') {
      await _takePhotoAndUpload();
    } else if (choice == 'gallery') {
      await _pickAndUploadFiles();
    }
  }

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;

    setState(() => _uploading = true);

    final entries = <MapEntry<String, Uint8List>>[];

    for (final file in result.files) {
      try {
        final name = file.name;
        final bytes = file.bytes ?? await io.File(file.path!).readAsBytes();
        entries.add(MapEntry(name, bytes));
      } catch (e) {
        debugPrint('Failed to read picked file "${file.name}": $e');
      }
    }

    await _uploadEntries(entries);

    if (mounted) setState(() => _uploading = false);
  }

  // Future<Uint8List> _compressImageSmart(Uint8List bytes, String name) async {
  //   if (kIsWeb) return bytes;

  //   if (bytes.lengthInBytes < 120 * 1024) return bytes;

  //   final ext = p.extension(name).toLowerCase();
  //   if (!_imageExtensions.contains(ext)) return bytes;

  //   try {
  //     final decoded = img.decodeImage(bytes);
  //     if (decoded == null) return bytes;

  //     const maxSide = 1024;
  //     const quality = 60;

  //     img.Image resized;
  //     if (decoded.width >= decoded.height) {
  //       resized = img.copyResize(
  //         decoded,
  //         width: maxSide,
  //         height: (decoded.height * maxSide / decoded.width).round(),
  //       );
  //     } else {
  //       resized = img.copyResize(
  //         decoded,
  //         height: maxSide,
  //         width: (decoded.width * maxSide / decoded.height).round(),
  //       );
  //     }

  //     final jpgBytes = img.encodeJpg(resized, quality: quality);
  //     return Uint8List.fromList(jpgBytes);
  //   } catch (e) {
  //     debugPrint('Compression error for $name: $e');
  //     return bytes;
  //   }
  // }

  Future<void> _uploadEntries(List<MapEntry<String, Uint8List>> entries) async {
    if (entries.isEmpty) return;

    final existingNames = _imageItems
        .map((f) => (f['name'] ?? '').toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    final uniqueEntries = <MapEntry<String, Uint8List>>[];
    int dupCount = 0;

    for (final e in entries) {
      final nameLower = e.key.toLowerCase();
      if (existingNames.contains(nameLower)) {
        dupCount++;
      } else {
        uniqueEntries.add(e);
      }
    }

    if (dupCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Juz masz fotka $dupCount w galerii.')),
      );
    }

    if (uniqueEntries.isEmpty) return;

    final processedEntries = <MapEntry<String, Uint8List>>[];

    for (final e in uniqueEntries) {
      final processed = await _compressAndConvert(e);
      processedEntries.add(processed);
    }

    final newFiles = await ProjectFilesService.uploadProjectFilesFromBytes(
      customerId: widget.customerId,
      projectId: widget.projectId,
      files: processedEntries,
    );

    if (mounted && newFiles.isNotEmpty) {
      setState(() {
        for (final f in newFiles) {
          _addIfImage(f);
        }
      });
    }
  }

  Widget _wrapWithDesktopDropTarget(Widget child) {
    if (!_isDesktop) return child;

    return DropTarget(
      onDragEntered: (detail) {
        setState(() => _dragging = true);
      },
      onDragExited: (detail) {
        setState(() => _dragging = false);
      },
      onDragDone: (detail) async {
        if (detail.files.isEmpty) return;
        await _handleDesktopDropFiles(detail.files);
        if (mounted) setState(() => _dragging = false);
      },
      child: child,
    );
  }

  void _openImageGallery(int sortedIndex) {
    if (_imageItems.isEmpty) return;

    final baseOrder = _getOrder(_imageItems);

    final order = baseOrder.where((idx) {
      if (_searchQuery.isEmpty) return true;
      final name = (_imageItems[idx]['name'] ?? '').toLowerCase();
      final url = (_imageItems[idx]['url'] ?? '').toLowerCase();
      return name.contains(_searchQuery) || url.contains(_searchQuery);
    }).toList();

    final orderedItems = order.map((i) => _imageItems[i]).toList();

    final bool isMobile =
        !kIsWeb &&
        !_isDesktop &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => isMobile
          ? _MobilePhotoGalleryDialog(
              items: orderedItems,
              initialIndex: sortedIndex.clamp(0, orderedItems.length - 1),
            )
          : _ImageGalleryDialog(
              items: orderedItems,
              initialIndex: sortedIndex.clamp(0, orderedItems.length - 1),
            ),
    );
  }

  Widget _buildImageTile(
    Map<String, String> file,
    int sortedIndex, {
    required double tileWidth,
    required double aspect,
  }) {
    final url = file['url'];
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    final bool isSelected = _selectionMode && _selectedUrls.contains(url);

    return SizedBox(
      width: tileWidth,
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () {
            if (_selectionMode) {
              _toggleSelection(url);
            } else {
              _openImageGallery(sortedIndex);
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: Colors.redAccent, width: 2)
                  : Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: aspect,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, stack) {
                    debugPrint('WEB IMAGE FAIL url=$url');
                    debugPrint('error=$error');
                    return const Center(child: Icon(Icons.broken_image));
                  },
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagesGrid(double boxHeight) {
    if (_imageItems.isEmpty) return const SizedBox.shrink();

    final orderedIndices = _getOrder(_imageItems);

    final filteredIndices = orderedIndices.where((idx) {
      if (_searchQuery.isEmpty) return true;
      final name = (_imageItems[idx]['name'] ?? '').toLowerCase();
      final url = (_imageItems[idx]['url'] ?? '').toLowerCase();
      return name.contains(_searchQuery) || url.contains(_searchQuery);
    }).toList();

    return SizedBox(
      height: boxHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;

          final w = constraints.maxWidth;
          final int cols = w >= 1100
              ? 8
              : w >= 900
              ? 7
              : w >= 720
              ? 6
              : w >= 560
              ? 5
              : w >= 360
              ? 4
              : 3;

          final tileWidth = (w - (spacing * (cols - 1))) / cols;

          final aspect = kIsWeb ? (4 / 3) : (3 / 2);

          return Scrollbar(
            thumbVisibility: kIsWeb,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(6),
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(filteredIndices.length, (i) {
                  final idx = filteredIndices[i];
                  final file = _imageItems[idx];
                  return _buildImageTile(
                    file,
                    i,
                    tileWidth: tileWidth,
                    aspect: aspect,
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uploading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasImages = _imageItems.isNotEmpty;

    if (!hasImages) {
      final isHighlighted = _dropHighlight || _dragging;

      final box = GestureDetector(
        onTap: _handleAddPressed,
        child: Container(
          height: kIsWeb ? 120 : 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? Colors.blueAccent : Colors.grey,
            ),
            borderRadius: BorderRadius.circular(6),
            color: isHighlighted
                ? Colors.blue.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Text(
            kIsWeb
                ? 'Kliknij lub upuść fotek tutaj'
                : 'Dotknij aby dodać fotek',
          ),
        ),
      );

      if (!kIsWeb) {
        return _wrapWithDesktopDropTarget(box);
      }

      return Stack(
        children: [
          Positioned.fill(
            child: DropzoneView(
              onCreated: (c) => _dropzoneController = c,
              operation: DragOperation.copy,
              onDropFiles: (files) {
                if (files == null || files.isEmpty) return;
                _handleWebDropFiles(files);
              },
              onHover: () => setState(() => _dropHighlight = true),
              onLeave: () => setState(() => _dropHighlight = false),
            ),
          ),
          box,
        ],
      );
    }

    final isHighlighted = _dropHighlight || _dragging;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProjectFilterRow(
            sortIsOriginal: _sort == _ImageSort.original,
            sortIsDateNewest: _sort == _ImageSort.dateNewest,
            sortIsType: _sort == _ImageSort.type,
            isAdmin: widget.isAdmin,
            selectionMode: _selectionMode,
            hasItems: _imageItems.isNotEmpty,
            onReset: () {
              setState(() {
                _sort = _ImageSort.original;
                _searchQuery = '';
              });
            },
            onSortOriginal: () {
              setState(() {
                _sort = _ImageSort.original;
              });
            },
            onSortDateNewest: () {
              setState(() {
                _sort = _ImageSort.dateNewest;
              });
            },
            onSortType: () {
              setState(() {
                _sort = _ImageSort.type;
              });
            },
            onClear: _imageItems.isEmpty ? null : _clearImages,
            onAdd: _handleAddPressed,
            onMove: _imageItems.isEmpty ? null : _moveImagesToFiles,
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Szukaj fotek',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
          ),
        ),

        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? Colors.blueAccent : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(6),
            color: isHighlighted
                ? Colors.blue.withValues(alpha: 0.02)
                : Colors.transparent,
          ),
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;

              final boxHeight = kIsWeb ? 240.0 : screenHeight * 0.6;

              return _buildImagesGrid(boxHeight);
            },
          ),
        ),

        const SizedBox(height: 4),
      ],
    );

    if (!kIsWeb) {
      final scrollable = SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: content,
      );
      return _wrapWithDesktopDropTarget(scrollable);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: DropzoneView(
            onCreated: (c) => _dropzoneController = c,
            operation: DragOperation.copy,
            onDropFiles: (files) {
              if (files == null || files.isEmpty) return;
              _handleWebDropFiles(files);
            },
            onHover: () => setState(() => _dropHighlight = true),
            onLeave: () => setState(() => _dropHighlight = false),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: _dropHighlight
                ? Border.all(color: Colors.blueAccent, width: 1.5)
                : null,
          ),
          padding: _dropHighlight ? const EdgeInsets.all(2) : EdgeInsets.zero,
          child: content,
        ),
      ],
    );
  }
}

enum _ImageClearScope { all, select }

class _ImageGalleryDialog extends StatefulWidget {
  final List<Map<String, String>> items;
  final int initialIndex;

  const _ImageGalleryDialog({required this.items, required this.initialIndex});

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (ctx, index) {
              final url = widget.items[index]['url']!;

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,

                      boundaryMargin: const EdgeInsets.all(200),

                      constrained: false,

                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.white70,
                            size: 64,
                          ),
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            top: 32,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${widget.items.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePhotoGalleryDialog extends StatefulWidget {
  final List<Map<String, String>> items;
  final int initialIndex;

  const _MobilePhotoGalleryDialog({
    required this.items,
    required this.initialIndex,
  });

  @override
  State<_MobilePhotoGalleryDialog> createState() =>
      _MobilePhotoGalleryDialogState();
}

class _MobilePhotoGalleryDialogState extends State<_MobilePhotoGalleryDialog> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              pageController: _controller,
              itemCount: widget.items.length,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              loadingBuilder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              builder: (ctx, index) {
                final url = widget.items[index]['url'] ?? '';

                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(url),
                  minScale: PhotoViewComputedScale.contained,
                  initialScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3.0,
                  heroAttributes: PhotoViewHeroAttributes(tag: url),
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
                );
              },
            ),

            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${widget.items.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
