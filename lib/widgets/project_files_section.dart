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
          const SnackBar(content: Text('Nie udało się usunąć pliku')),
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
        ).showSnackBar(const SnackBar(content: Text('Nie można pobrać pliku')));
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
            const SnackBar(content: Text('Nie można otworzyć pliku')),
          );
        }
      } catch (e) {
        debugPrint('Failed to open file on web: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie można otworzyć pliku')),
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

  Widget _buildFileTile(Map<String, String> file, int index) {
    final name = file['name'] ?? '';

    return SizedBox(
      width: 260,
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => _previewFile(file['url']!, name),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: name,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Pobierz',
                  icon: const Icon(Icons.download, size: 18),
                  onPressed: () => _downloadFile(file['url']!, name),
                ),
                if (widget.isAdmin)
                  GestureDetector(
                    onTap: () => _deleteItem(isImage: false, index: index),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageTile(Map<String, String> file, int index) {
    final name = file['name'] ?? '';
    final url = file['url']!;

    return SizedBox(
      width: 180,
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => _previewFile(url, name),
          borderRadius: BorderRadius.circular(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: name,
                        waitDuration: const Duration(milliseconds: 500),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pobierz',
                      icon: const Icon(Icons.download, size: 18),
                      onPressed: () => _downloadFile(url, name),
                    ),
                    if (widget.isAdmin)
                      GestureDetector(
                        onTap: () => _deleteItem(isImage: true, index: index),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.close, size: 16, color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilesSection() {
    if (_fileItems.isEmpty) return const SizedBox.shrink();

    final order = _getOrder(_fileItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Text(
            'Pliki',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(order.length, (i) {
              final idx = order[i];
              return _buildFileTile(_fileItems[idx], idx);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildImagesSection() {
    if (_imageItems.isEmpty) return const SizedBox.shrink();

    final order = _getOrder(_imageItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(
            'Zdjęcia',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(order.length, (i) {
              final idx = order[i];
              return _buildImageTile(_imageItems[idx], idx);
            }),
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

    final listContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sort chips – apply to both files & images
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Sortuj:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              ChoiceChip(
                label: const Text('Domyślnie'),
                selected: _fileSort == _FileSort.original,
                onSelected: (_) {
                  setState(() => _fileSort = _FileSort.original);
                },
              ),
              ChoiceChip(
                label: const Text('Data'),
                selected: _fileSort == _FileSort.dateNewest,
                onSelected: (_) {
                  setState(() => _fileSort = _FileSort.dateNewest);
                },
              ),
              ChoiceChip(
                label: const Text('Typ pliku'),
                selected: _fileSort == _FileSort.type,
                onSelected: (_) {
                  setState(() => _fileSort = _FileSort.type);
                },
              ),
            ],
          ),
        ),
        // Main bordered container with scrollable files + images
        Container(
          constraints: BoxConstraints(maxHeight: kIsWeb ? 280 : 160),
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
          child: Scrollbar(
            thumbVisibility: kIsWeb,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasFiles) _buildFilesSection(),
                  if (hasFiles && hasImages) const SizedBox(height: 8),
                  if (hasImages) _buildImagesSection(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Add button – same for both, auto-routing by extension
        GestureDetector(
          onTap: _pickAndUploadFiles,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueAccent),
              borderRadius: BorderRadius.circular(6),
              color: Colors.blue.withValues(alpha: 0.05),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 16),
                SizedBox(width: 6),
                Text(
                  'dodaj pliki / zdjęcia',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!kIsWeb) {
      return _wrapWithDesktopDropTarget(listContent);
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
          child: listContent,
        ),
      ],
    );
  }
}
