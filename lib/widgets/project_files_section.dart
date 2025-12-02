// lib/widgets/project_files_section.dart
import 'dart:io' as io;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:strefa_ciszy/services/project_files_service.dart';
import 'package:url_launcher/url_launcher.dart';

enum _FileSort { original, dateNewest, type }

enum _ClearScope { all, files, images, select }

class ProjectFilesSection extends StatefulWidget {
  final String customerId;
  final String projectId;
  final bool isAdmin;
  final List<Map<String, String>> initialFiles;

  const ProjectFilesSection({
    super.key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
    this.initialFiles = const [],
  });

  @override
  State<ProjectFilesSection> createState() => _ProjectFilesSectionState();
}

class _ProjectFilesSectionState extends State<ProjectFilesSection> {
  // Separate lists for normal files and images
  final List<Map<String, String>> _fileItems = [];
  final List<Map<String, String>> _imageItems = [];

  bool _fileUploading = false;
  DropzoneViewController? _dropzoneController;
  bool _dropHighlight = false;
  bool _dragging = false;
  _FileSort _fileSort = _FileSort.original;
  bool _selectionMode = false;
  final Set<String> _selectedUrls = {};

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

  @override
  void initState() {
    super.initState();
    for (final f in widget.initialFiles) {
      _addItemToCorrectList(f);
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

  bool get _isDesktop {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  bool _isImageName(String name) {
    final ext = p.extension(name).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  void _addItemToCorrectList(Map<String, String> item) {
    final name = item['name'] ?? '';
    if (_isImageName(name)) {
      _imageItems.add(item);
    } else {
      _fileItems.add(item);
    }
  }

  Future<void> _clearItems() async {
    if (!widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tylko admin może skasować')),
      );
      return;
    }
    if (_fileItems.isEmpty && _imageItems.isEmpty) return;

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
          title: const Text('Usuń zaznaczone'),
          content: Text(
            'Na pewno chcesz usunąć ${_selectedUrls.length} tych elementów?',
          ),
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

      setState(() => _fileUploading = true);

      try {
        Future<void> deleteList(List<Map<String, String>> list) async {
          final copy = List<Map<String, String>>.from(list);
          for (final f in copy) {
            final url = f['url']!;
            if (!_selectedUrls.contains(url)) continue;

            await ProjectFilesService.deleteProjectFile(
              customerId: widget.customerId,
              projectId: widget.projectId,
              url: url,
              name: f['name']!,
            );
            list.remove(f);
          }
        }

        await deleteList(_fileItems);
        await deleteList(_imageItems);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zaznaczone pliki usunięte')),
          );
        }
      } catch (e) {
        debugPrint('Bulk delete selected error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nie udało się skasować plików')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _fileUploading = false;
            _selectionMode = false;
            _selectedUrls.clear();
          });
        }
      }

      return;
    }

    // Normal mode → ask what to delete / or enter selection mode
    final choice = await showDialog<_ClearScope>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń pliki / fotki'),
        content: const Text('Co chcesz usunąć?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ClearScope.files),
            child: const Text('Tylko pliki'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ClearScope.images),
            child: const Text('Tylko zdjęcia'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ClearScope.select),
            child: const Text('Wybierz kilka'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _ClearScope.all),
            child: const Text('Wszystko'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == _ClearScope.select) {
      setState(() {
        _selectionMode = true;
        _selectedUrls.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Wybierz pliki / foty do usunecie, '
              'potem ponownie kliknij Wyczyść',
            ),
          ),
        );
      }
      return;
    }

    final clearFiles = choice == _ClearScope.all || choice == _ClearScope.files;
    final clearImages =
        choice == _ClearScope.all || choice == _ClearScope.images;

    setState(() => _fileUploading = true);

    try {
      if (clearFiles && _fileItems.isNotEmpty) {
        final filesCopy = List<Map<String, String>>.from(_fileItems);
        for (final f in filesCopy) {
          await ProjectFilesService.deleteProjectFile(
            customerId: widget.customerId,
            projectId: widget.projectId,
            url: f['url']!,
            name: f['name']!,
          );
        }
        _fileItems.clear();
      }

      if (clearImages && _imageItems.isNotEmpty) {
        final imagesCopy = List<Map<String, String>>.from(_imageItems);
        for (final f in imagesCopy) {
          await ProjectFilesService.deleteProjectFile(
            customerId: widget.customerId,
            projectId: widget.projectId,
            url: f['url']!,
            name: f['name']!,
          );
        }
        _imageItems.clear();
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pliki usunięte')));
      }
    } catch (e) {
      debugPrint('Bulk clear error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się skasować plików')),
        );
      }
    } finally {
      if (mounted) setState(() => _fileUploading = false);
    }
  }

  List<int> _getOrder(List<Map<String, String>> items) {
    final idxs = List<int>.generate(items.length, (i) => i);

    switch (_fileSort) {
      case _FileSort.original:
        return idxs;

      case _FileSort.dateNewest:
        // Newest by insertion order – last added first
        idxs.sort((a, b) => b.compareTo(a));
        return idxs;

      case _FileSort.type:
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

  Future<void> _handleDesktopDropFiles(List<XFile> dropped) async {
    if (dropped.isEmpty) return;

    setState(() => _fileUploading = true);

    final entries = <MapEntry<String, Uint8List>>[];

    for (final xf in dropped) {
      try {
        final bytes = await xf.readAsBytes();
        entries.add(MapEntry(xf.name, bytes));
      } catch (e) {
        debugPrint('Failed to read dropped file "${xf.name}": $e');
      }
    }

    if (entries.isNotEmpty) {
      final newFiles = await ProjectFilesService.uploadProjectFilesFromBytes(
        customerId: widget.customerId,
        projectId: widget.projectId,
        files: entries,
      );

      if (mounted && newFiles.isNotEmpty) {
        setState(() {
          for (final f in newFiles) {
            _addItemToCorrectList(f);
          }
        });
      }
    }

    if (mounted) setState(() => _fileUploading = false);
  }

  Future<void> _handleWebDropFiles(List<DropzoneFileInterface> files) async {
    if (!kIsWeb) return;

    if (_dropzoneController == null) {
      debugPrint('Dropzone controller is null');
      return;
    }

    if (files.isEmpty) return;

    setState(() => _fileUploading = true);

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

      if (entries.isNotEmpty) {
        final newFiles = await ProjectFilesService.uploadProjectFilesFromBytes(
          customerId: widget.customerId,
          projectId: widget.projectId,
          files: entries,
        );

        if (mounted && newFiles.isNotEmpty) {
          setState(() {
            for (final f in newFiles) {
              _addItemToCorrectList(f);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Drop upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się wysłać pliku')),
        );
      }
    } finally {
      if (mounted) setState(() => _fileUploading = false);
    }
  }

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    setState(() => _fileUploading = true);

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

    if (entries.isNotEmpty) {
      final newFiles = await ProjectFilesService.uploadProjectFilesFromBytes(
        customerId: widget.customerId,
        projectId: widget.projectId,
        files: entries,
      );

      if (mounted && newFiles.isNotEmpty) {
        setState(() {
          for (final f in newFiles) {
            _addItemToCorrectList(f);
          }
        });
      }
    }

    if (mounted) setState(() => _fileUploading = false);
  }

  Future<void> _deleteItem({required bool isImage, required int index}) async {
    if (!widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tylko admin może skasować')),
      );
      return;
    }
    final list = isImage ? _imageItems : _fileItems;
    final file = list[index];
    final url = file['url']!;
    final name = file['name']!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń plik?'),
        content: Text('Na pewno chcesz usunąć plik "$name"?'),
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

    setState(() => _fileUploading = true);

    try {
      await ProjectFilesService.deleteProjectFile(
        customerId: widget.customerId,
        projectId: widget.projectId,
        url: url,
        name: name,
      );

      setState(() {
        list.removeAt(index);
      });
    } catch (e) {
      debugPrint('Failed to delete file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się usunąć plik')),
        );
      }
    } finally {
      if (mounted) setState(() => _fileUploading = false);
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    if (kIsWeb) {
      final uri = Uri.parse(url);
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      final response = await http.get(Uri.parse(url));
      final file = io.File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Zapisano do pliku: $fileName')));
      }
    } catch (e) {
      debugPrint('Failed to download file: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nie można pobrać plik')));
      }
    }
  }

  Future<void> _previewFile(String url, String fileName) async {
    if (kIsWeb) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
            webOnlyWindowName: '_blank',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nie można otworzyć plik')),
          );
        }
      } catch (e) {
        debugPrint('Failed to open file on web: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie można otworzyć plik')),
        );
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      final response = await http.get(Uri.parse(url));
      final file = io.File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint('Failed to open file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie można otworzyć plik')),
        );
      }
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

  // files box
  Widget _buildFileTile(Map<String, String> file, int index) {
    final name = file['name'] ?? '';
    final url = file['url']!;

    final bool isWeb = kIsWeb;
    final bool isSelected = _selectionMode && _selectedUrls.contains(url);

    double tileWidth;
    if (isWeb) {
      tileWidth = 260.0;
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      final availableWidth = screenWidth - 32.0;
      tileWidth = (availableWidth - 8.0) / 2; // 2 per row
    }

    final double textSize = isWeb ? 13.0 : 11.0;
    final double vPadding = isWeb ? 8.0 : 4.0;
    final double hPadding = isWeb ? 12.0 : 8.0;

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
              _previewFile(url, name);
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: Colors.redAccent, width: 2)
                  : null,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: hPadding,
              vertical: vPadding,
            ),
            child: Tooltip(
              message: name,
              waitDuration: const Duration(milliseconds: 500),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // images box
  Widget _buildImageTile(Map<String, String> file, int index) {
    final name = file['name'] ?? '';
    final url = file['url']!;
    final bool isWeb = kIsWeb;
    final bool isSelected = _selectionMode && _selectedUrls.contains(url);

    double tileWidth;
    if (isWeb) {
      tileWidth = 80.0;
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      final tilesPerRow = screenWidth < 360 ? 3 : 4;
      final availableWidth = screenWidth - 32.0;
      tileWidth =
          (availableWidth - 8.0 * (tilesPerRow - 1)) /
          tilesPerRow; // 3–4 per row
    }

    final double aspect = isWeb ? (4 / 3) : (3 / 2);

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
              _previewFile(url, name);
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: Colors.redAccent, width: 2)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: aspect,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// FILES
  Widget _buildFilesSection(double boxHeight) {
    if (_fileItems.isEmpty) return const SizedBox.shrink();

    final order = _getOrder(_fileItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kIsWeb) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Text(
              'Pliki',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: boxHeight,
          child: Scrollbar(
            thumbVisibility: kIsWeb,
            child: ListView(
              padding: const EdgeInsets.all(6),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(order.length, (i) {
                    final idx = order[i];
                    return _buildFileTile(_fileItems[idx], idx);
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// IMAGES
  Widget _buildImagesSection(double boxHeight) {
    if (_imageItems.isEmpty) return const SizedBox.shrink();

    final order = _getOrder(_imageItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kIsWeb) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Text(
              'Zdjęcia',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: boxHeight,
          child: Scrollbar(
            thumbVisibility: kIsWeb,
            child: ListView(
              padding: const EdgeInsets.all(6),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(order.length, (i) {
                    final idx = order[i];
                    return _buildImageTile(_imageItems[idx], idx);
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fileUploading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasFiles = _fileItems.isNotEmpty;
    final hasImages = _imageItems.isNotEmpty;

    // EMPTY STATE – no files or images yet
    if (!hasFiles && !hasImages) {
      final isHighlighted = _dropHighlight || _dragging;

      final box = GestureDetector(
        onTap: _pickAndUploadFiles,
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
                ? 'Kliknij lub upuść pliki / zdjęcia tutaj'
                : 'Dotknij aby dodać plik / zdjęcie',
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

    //  filters
    final listContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Icon(Icons.refresh),
                selected: _fileSort == _FileSort.original,
                onSelected: (_) {
                  setState(() => _fileSort = _FileSort.original);
                },
              ),
              ChoiceChip(
                label: const Text('Date'),
                selected: _fileSort == _FileSort.dateNewest,
                onSelected: (_) {
                  setState(() => _fileSort = _FileSort.dateNewest);
                },
              ),
              ChoiceChip(
                label: const Text('Typ'),
                selected: _fileSort == _FileSort.type,
                onSelected: (_) {
                  setState(() => _fileSort = _FileSort.type);
                },
              ),

              // CLEAR (admin)
              if (widget.isAdmin)
                ChoiceChip(
                  // avatar: Icon(
                  //   Icons.delete_outline,
                  //   size: 16,
                  //   color: _selectionMode ? Colors.red : Colors.black54,
                  // ),
                  // label: const SizedBox.shrink(),
                  label: Text('Skasuj', style: TextStyle(color: Colors.red)),
                  labelPadding: EdgeInsets.zero,
                  selected: _selectionMode,
                  onSelected: (_fileItems.isEmpty && _imageItems.isEmpty)
                      ? null
                      : (_) => _clearItems(),
                  backgroundColor: Colors.transparent,
                  selectedColor: Colors.red.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: _selectionMode ? Colors.red : Colors.grey.shade400,
                  ),
                ),

              // ADD
              ChoiceChip(
                // avatar: const Icon(Icons.add, size: 16),
                label: Text(
                  'Dodaj',
                  style: TextStyle(color: Colors.green.shade800),
                ),
                labelPadding: EdgeInsets.zero,
                selected: false,
                onSelected: (_) => _pickAndUploadFiles(),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: Colors.blueAccent),
              ),
            ],
          ),
        ),

        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: (_dropHighlight || _dragging)
                  ? Colors.blueAccent
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(6),
            color: (_dropHighlight || _dragging)
                ? Colors.blue.withValues(alpha: 0.02)
                : Colors.transparent,
          ),
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final boxHeight = kIsWeb ? 240.0 : 70.0;

              final filesBox = hasFiles
                  ? _buildFilesSection(boxHeight)
                  : const SizedBox.shrink();
              final imagesBox = hasImages
                  ? _buildImagesSection(boxHeight)
                  : const SizedBox.shrink();

              if (isWide) {
                // 2 boxes side by side
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasFiles) Expanded(child: filesBox),
                    if (hasFiles && hasImages) const SizedBox(width: 12),
                    if (hasImages) Expanded(child: imagesBox),
                  ],
                );
              } else {
                // PHONE: boxes stacked
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasFiles) filesBox,
                    if (hasFiles && hasImages)
                      kIsWeb
                          ? const SizedBox(height: 18)
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(height: 1, thickness: 0.8),
                            ),
                    if (hasImages) imagesBox,
                  ],
                );
              }
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );

    if (!kIsWeb) {
      return _wrapWithDesktopDropTarget(listContent);
    }

    // WEB: dropzone
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
          child: listContent,
        ),
      ],
    );
  }
}
