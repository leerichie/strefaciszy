// lib/widgets/project_files_only_section.dart
import 'dart:async';
import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:strefa_ciszy/widgets/project_filter_row.dart';
import 'package:url_launcher/url_launcher.dart';

enum _FileSort { original, dateNewest, type }

enum _ClearScope { all, select }

class ProjectFilesOnlySection extends StatefulWidget {
  final String customerId;
  final String projectId;
  final bool isAdmin;
  final List<Map<String, String>> initialFiles;
  final bool readOnly;

  const ProjectFilesOnlySection({
    super.key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
    this.initialFiles = const [],
    this.readOnly = false,
  });

  @override
  State<ProjectFilesOnlySection> createState() =>
      _ProjectFilesOnlySectionState();
}

class _ProjectFilesOnlySectionState extends State<ProjectFilesOnlySection> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _projectSub;

  final List<Map<String, String>> _fileItems = [];

  bool _uploading = false;
  DropzoneViewController? _dropzoneController;
  bool _dropHighlight = false;
  bool _dragging = false;
  _FileSort _fileSort = _FileSort.original;
  ProjectActionMode _actionMode = ProjectActionMode.none;
  final Set<String> _selectedUrls = {};
  String _searchQuery = '';
  bool get _isSelecting => _actionMode != ProjectActionMode.none;
  bool get _canEdit => widget.isAdmin && !widget.readOnly;

  void _exitActionMode() {
    setState(() {
      _actionMode = ProjectActionMode.none;
      _selectedUrls.clear();
    });
  }

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
    for (final f in widget.initialFiles) {}
    final ref = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    _projectSub = ref.snapshots().listen((snap) {
      final data = snap.data();
      if (!mounted || data == null) return;

      final files = data['files'];
      if (files is! List) return;

      final List<Map<String, String>> next = [];

      for (final f in files) {
        if (f is! Map) continue;

        final url = f['url'];
        final name = f['name'];
        final bucket = (f['bucket'] ?? '').toString();

        if (url is! String || name is! String) continue;
        if (bucket != 'files') continue;

        next.add({'url': url, 'name': name, 'bucket': bucket});
      }

      setState(() {
        _fileItems
          ..clear()
          ..addAll(next);

        _selectedUrls.removeWhere((u) => !_fileItems.any((e) => e['url'] == u));
      });
    });
  }

  @override
  void dispose() {
    _projectSub?.cancel();
    super.dispose();
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

  // Future<void> _openSearchDialog() async {
  //   final controller = TextEditingController(text: _searchQuery);

  //   await showDialog<void>(
  //     context: context,
  //     builder: (ctx) {
  //       return AlertDialog(
  //         title: const Text('Szukaj plików'),
  //         content: TextField(
  //           controller: controller,
  //           autofocus: true,
  //           decoration: const InputDecoration(
  //             labelText: 'Nazwa pliku',
  //             border: OutlineInputBorder(),
  //           ),
  //           onChanged: (value) {
  //             setState(() {
  //               _searchQuery = value.trim().toLowerCase();
  //             });
  //           },
  //           onSubmitted: (_) {
  //             Navigator.of(ctx).pop();
  //           },
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               controller.clear();
  //               setState(() => _searchQuery = '');
  //             },
  //             child: const Text('Wyczyść'),
  //           ),
  //           TextButton(
  //             onPressed: () => Navigator.of(ctx).pop(),
  //             child: const Text('Zamknij'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  List<int> _getOrder(List<Map<String, String>> items) {
    final idxs = List<int>.generate(items.length, (i) => i);

    switch (_fileSort) {
      case _FileSort.original:
        return idxs;

      case _FileSort.dateNewest:
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

  Future<void> _clearFiles() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tylko podgląd')));
      return;
    }
    if (_fileItems.isEmpty) return;

    if (_actionMode == ProjectActionMode.delete) {
      if (_selectedUrls.isEmpty) {
        _exitActionMode();
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Usuń zaznaczone pliki'),
          content: Text(
            'Na pewno chcesz usunąć ${_selectedUrls.length} plików?',
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

      setState(() => _uploading = true);

      try {
        final copy = List<Map<String, String>>.from(_fileItems);
        for (final f in copy) {
          final url = f['url']!;
          if (!_selectedUrls.contains(url)) continue;

          await ProjectFilesService.deleteProjectFile(
            customerId: widget.customerId,
            projectId: widget.projectId,
            url: url,
            name: f['name']!,
            bucket: (f['bucket'] ?? 'files'),
          );

          _fileItems.remove(f);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zaznaczone pliki usunięte')),
          );
        }
      } catch (e) {
        debugPrint('Bulk delete selected files error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nie udało się skasować plików')),
          );
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
        _exitActionMode();
      }

      return;
    }

    final choice = await showDialog<_ClearScope>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń pliki'),
        content: const Text('Co chcesz usunąć?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ClearScope.select),
            child: const Text('Wybierz kilka'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _ClearScope.all),
            child: const Text('Wszystkie'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == _ClearScope.select) {
      setState(() {
        _actionMode = ProjectActionMode.delete;
        _selectedUrls.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wybierz pliki do usunięcia, potem kliknij Usuń'),
          ),
        );
      }
      return;
    }

    // ALL
    setState(() => _uploading = true);

    try {
      final copy = List<Map<String, String>>.from(_fileItems);
      for (final f in copy) {
        await ProjectFilesService.deleteProjectFile(
          customerId: widget.customerId,
          projectId: widget.projectId,
          url: f['url']!,
          name: f['name']!,
          bucket: (f['bucket'] ?? 'files'),
        );
      }
      _fileItems.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wszystkie pliki usunięte')),
        );
      }
    } catch (e) {
      debugPrint('Bulk clear files error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się skasować plików')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
      _exitActionMode();
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

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
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

  Future<void> _uploadEntries(List<MapEntry<String, Uint8List>> entries) async {
    if (entries.isEmpty) return;

    // existing file names (lowercased)
    final existingNames = _fileItems
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Juz masz $dupCount w folderze!')));
    }

    if (uniqueEntries.isEmpty) return;

    final newFiles = await ProjectFilesService.uploadProjectFilesFromBytes(
      customerId: widget.customerId,
      projectId: widget.projectId,
      files: uniqueEntries,
      tabBucket: 'files',
    );

    if (mounted && newFiles.isNotEmpty) {
      setState(() {
        for (final f in newFiles) {}
      });
    }
  }

  Future<void> _previewFile(String url, String fileName) async {
    // WEB
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

    // MOBILE
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (e) {
      debugPrint('External open failed, fallback to download: $e');
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
          const SnackBar(content: Text('Nie można otworzyć pliku')),
        );
      }
    }
  }

  Widget _wrapWithDesktopDropTarget(Widget child) {
    if (!_isDesktop || !_canEdit) return child;

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
    final url = file['url']!;
    final bool isWeb = kIsWeb;
    final bool isSelected = _isSelecting && _selectedUrls.contains(url);

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
            if (_isSelecting) {
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

  Widget _buildFilesGrid(double boxHeight) {
    if (_fileItems.isEmpty) return const SizedBox.shrink();

    final baseOrder = _getOrder(_fileItems);
    final order = baseOrder.where((idx) {
      if (_searchQuery.isEmpty) return true;
      final name = (_fileItems[idx]['name'] ?? '').toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    return SizedBox(
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
                final file = _fileItems[idx];
                return _buildFileTile(file, idx);
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uploading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasFiles = _fileItems.isNotEmpty;

    // EMPTY STATE
    if (!hasFiles) {
      final isHighlighted = _dropHighlight || _dragging;

      final box = GestureDetector(
        onTap: _canEdit ? _pickAndUploadFiles : null,
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
            _canEdit
                ? (kIsWeb
                      ? 'Kliknij lub upusc pliki tutaj'
                      : 'Dotknij aby dodać pliki')
                : 'Brak plików',
          ),
        ),
      );

      if (!kIsWeb) {
        return _wrapWithDesktopDropTarget(box);
      }

      return Stack(
        children: [
          if (_canEdit)
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
          padding: const EdgeInsets.only(bottom: 4),
          child: ProjectFilterRow(
            sortIsOriginal: _fileSort == _FileSort.original,
            sortIsDateNewest: _fileSort == _FileSort.dateNewest,
            sortIsType: _fileSort == _FileSort.type,
            isAdmin: widget.isAdmin,
            actionMode: _actionMode,
            hasItems: _fileItems.isNotEmpty,

            onReset: () {
              setState(() {
                _fileSort = _FileSort.original;
                _searchQuery = '';
                _exitActionMode();
              });
            },

            onSortOriginal: () =>
                setState(() => _fileSort = _FileSort.original),
            onSortDateNewest: () =>
                setState(() => _fileSort = _FileSort.dateNewest),
            onSortType: () => setState(() => _fileSort = _FileSort.type),

            onClear: (!_canEdit || _fileItems.isEmpty) ? null : _clearFiles,
            onAdd: () {
              if (_canEdit) {
                _pickAndUploadFiles();
              }
            },
            onMove: null,
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Szukaj plików',
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

              return _buildFilesGrid(boxHeight);
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
        if (_canEdit)
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
