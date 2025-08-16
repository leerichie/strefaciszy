// lib/screens/project_description_screen.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io' as io;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:strefa_ciszy/screens/location_picker_screen.dart';
import 'package:strefa_ciszy/services/storage_service.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:strefa_ciszy/widgets/app_drawer.dart';

enum _PhotoSource { camera, gallery }

class NoSwipeCupertinoRoute<T> extends CupertinoPageRoute<T> {
  NoSwipeCupertinoRoute({required super.builder});

  @override
  bool get popGestureEnabled => false;
}

class ProjectDescriptionScreen extends StatefulWidget {
  final String customerId;
  final String projectId;
  final bool isAdmin;

  const ProjectDescriptionScreen({
    super.key,
    required this.customerId,
    required this.projectId,
    this.isAdmin = false,
  });

  @override
  _ProjectDescriptionScreenState createState() =>
      _ProjectDescriptionScreenState();
}

class _ProjectDescriptionScreenState extends State<ProjectDescriptionScreen> {
  List<Map<String, String>> _files = [];
  bool _fileUploading = false;
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  bool _loading = true;
  final bool _saving = false;
  bool _uploading = false;
  final _addressCtrl = TextEditingController();
  GoogleMapController? _mapController;
  String _customerName = '';
  String _projectName = '';

  LatLng? _location;
  List<String> _photoUrls = [];
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImages = [];
  final _storageService = StorageService();
  Timer? _descDebounce;
  late final VoidCallback _descListener;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _locSub;

  @override
  void initState() {
    super.initState();
    _loadDescription();
    _descListener = () => _onDescChanged(_descCtrl.text);
    _descCtrl.addListener(_descListener);

    _loadNames();

    _locSub = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .snapshots()
        .listen((snap) {
          final data = snap.data();
          if (data == null) return;

          final gp = data['location'] as GeoPoint?;
          if (gp != null) {
            final newLoc = LatLng(gp.latitude, gp.longitude);
            if (_mapController != null) {
              _mapController!.animateCamera(CameraUpdate.newLatLng(newLoc));
            }

            setState(() {
              _location = newLoc;
              _addressCtrl.text =
                  data['address'] as String? ?? _addressCtrl.text;
            });
          }
        });
  }

  void _onDescChanged(String value) {
    if (_descDebounce?.isActive ?? false) _descDebounce!.cancel();
    _descDebounce = Timer(const Duration(milliseconds: 500), () async {
      final trimmed = value.trim();
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .update({
            'description': trimmed,
            'descriptionUpdatedAt': FieldValue.serverTimestamp(),
          });
    });
  }

  Future<void> _loadNames() async {
    final custDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .get();
    final projDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .get();

    if (!mounted) return;
    setState(() {
      _customerName = custDoc.data()?['name'] as String? ?? '';
      _projectName = projDoc.data()?['title'] as String? ?? '';
    });
  }

  Future<void> _loadDescription() async {
    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .get();

    final data = doc.data();
    if (data != null) {
      if (data['description'] is String) {
        _descCtrl.text = data['description'] as String;
      }
      if (data['address'] is String) {
        _addressCtrl.text = data['address'] as String;
      }
      if (data['location'] is GeoPoint) {
        final gp = data['location'] as GeoPoint;
        _location = LatLng(gp.latitude, gp.longitude);
      }
      if (data['photos'] is List) {
        _photoUrls = List<String>.from(data['photos']);
      }
      if (data['files'] is List) {
        _files = List<Map<String, String>>.from(
          (data['files'] as List).map((e) => Map<String, String>.from(e)),
        );
      }

      _photoUrls = List<String>.from(data['photos'] ?? []);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _openGallery(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageGalleryScreen(
          images: List.from(_photoUrls),
          initialIndex: initialIndex,
          onDelete: (url) async {
            final docRef = FirebaseFirestore.instance
                .collection('customers')
                .doc(widget.customerId)
                .collection('projects')
                .doc(widget.projectId);
            await docRef.update({
              'photos': FieldValue.arrayRemove([url]),
            });
            setState(() => _photoUrls.remove(url));
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _deletePhoto(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń zdjęcie?'),
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

    setState(() => _uploading = true);
    final docRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    await docRef.update({
      'photos': FieldValue.arrayRemove([url]),
    });
    setState(() {
      _photoUrls.remove(url);
      _uploading = false;
    });
  }

  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.of(context).push<LatLng>(
      NoSwipeCupertinoRoute<LatLng>(
        builder: (_) => LocationPickerScreen(
          initialLocation: _location,
          customerId: widget.customerId,
          projectId: widget.projectId,
        ),
      ),
    );

    if (result != null) {
      setState(() => _location = result);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(result, 15));
      final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '${result.latitude},${result.longitude}',
        'key': 'AIzaSyACykl4m8C7NUTXfoyQ7PQve-3Zqjxqeoc',
      });
      final resp = await http.get(url);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      String? formatted;
      if (body['status'] == 'OK' && (body['results'] as List).isNotEmpty) {
        formatted = (body['results'][0]['formatted_address'] as String);
        _addressCtrl.text = formatted;
      }
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .update({
            'location': GeoPoint(result.latitude, result.longitude),
            if (formatted != null) 'address': formatted,
          });
    }
  }

  Future<void> _searchAddress() async {
    final input = _addressCtrl.text.trim();
    if (input.isEmpty) return;

    FocusScope.of(context).unfocus();

    if (input.startsWith('http://') || input.startsWith('https://')) {
      final uri = Uri.parse(input);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie można otworzyć linku')),
        );
      }
      return;
    }

    final geoUri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': input,
      'key': 'AIzaSyACykl4m8C7NUTXfoyQ7PQve-3Zqjxqeoc',
    });

    try {
      final resp = await http.get(geoUri);
      final map = jsonDecode(resp.body) as Map<String, dynamic>;

      if (map['status'] == 'OK' && (map['results'] as List).isNotEmpty) {
        final loc =
            (map['results'][0]['geometry']['location']) as Map<String, dynamic>;
        final newPos = LatLng(loc['lat'] as double, loc['lng'] as double);

        setState(() => _location = newPos);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .collection('projects')
            .doc(widget.projectId)
            .update({
              'location': GeoPoint(newPos.latitude, newPos.longitude),
              'address': map['results'][0]['formatted_address'] as String,
            });
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nie znaleziono miejsca')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Błąd podczas wyszukiwania')),
      );
    }
  }

  Future<void> _launchNavigation() async {
    if (_location == null) return;

    final lat = _location!.latitude;
    final lng = _location!.longitude;

    // Android navi; fallback to web
    final googleNavUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleMapsWebUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    // iOS: Apple Maps, fallback to web
    final appleNavUrl = Uri.parse('maps://?daddr=$lat,$lng&dirflg=d');
    final appleMapsWebUrl = Uri.parse(
      'https://maps.apple.com/?daddr=$lat,$lng',
    );

    if (Theme.of(context).platform == TargetPlatform.android) {
      if (await canLaunchUrl(googleNavUrl)) {
        await launchUrl(googleNavUrl);
      } else {
        await launchUrl(googleMapsWebUrl);
      }
    } else {
      if (await canLaunchUrl(appleNavUrl)) {
        await launchUrl(appleNavUrl);
      } else {
        await launchUrl(appleMapsWebUrl);
      }
    }
  }

  Future<void> _showPhotoSourceDialog() async {
    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Zrób fota'),
                onTap: () => Navigator.pop(ctx, _PhotoSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Wybierz z galerii'),
                onTap: () => Navigator.pop(ctx, _PhotoSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == _PhotoSource.camera) {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo != null) await _uploadPickedImages([photo]);
    } else if (source == _PhotoSource.gallery) {
      final photos = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photos.isNotEmpty) {
        await _uploadPickedImages(photos);
      }
    }
  }

  Future<void> _uploadPickedImages(List<XFile> files) async {
    setState(() => _uploading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.getIdToken(true);

    final bucketName = Firebase.app().options.storageBucket;
    final storage = FirebaseStorage.instanceFor(
      app: Firebase.app(),
      bucket: 'gs://$bucketName',
    );

    final List<String> newUrls = [];

    for (final xfile in files) {
      final ext = p.extension(xfile.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final ref = storage.ref().child(
        'project_images/${widget.projectId}/$fileName',
      );

      Uint8List bytes;
      try {
        bytes = await xfile.readAsBytes();
      } catch (e) {
        debugPrint('⚠️ Failed to read "${xfile.name}": $e');
        continue;
      }

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      try {
        final snapshot = await uploadTask;
        if (snapshot.state != TaskState.success) continue;
        final url = await ref.getDownloadURL();
        newUrls.add(url);
      } catch (e) {
        debugPrint('❌ Upload failed for $fileName: $e');
      }
    }

    if (newUrls.isNotEmpty) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .collection('projects')
            .doc(widget.projectId);

        await docRef.update({'photos': FieldValue.arrayUnion(newUrls)});

        setState(() {
          _photoUrls.addAll(newUrls);
        });
      } catch (e) {
        debugPrint('❌ Firestore update error → $e');
      }
    }

    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _pickAndUploadFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    setState(() => _fileUploading = true);
    final bucket = Firebase.app().options.storageBucket;
    final storage = FirebaseStorage.instanceFor(bucket: 'gs://$bucket');
    final newFiles = <Map<String, String>>[];

    for (final file in result.files) {
      final name = file.name;
      final data = file.bytes ?? await io.File(file.path!).readAsBytes();
      final ref = storage.ref().child(
        'project_files/${widget.projectId}/$name',
      );

      await ref.putData(data);
      final url = await ref.getDownloadURL();
      newFiles.add({'url': url, 'name': name});
    }

    final docRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    await docRef.update({'files': FieldValue.arrayUnion(newFiles)});

    setState(() {
      _files.addAll(newFiles);
      _fileUploading = false;
    });
  }

  Future<void> _deleteFile(int index) async {
    final file = _files[index];
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

    final storage = FirebaseStorage.instanceFor(
      bucket: 'gs://${Firebase.app().options.storageBucket}',
    );
    try {
      await storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('⚠️ Couldn’t delete from storage: $e');
    }

    final docRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    await docRef.update({
      'files': FieldValue.arrayRemove([
        {'url': url, 'name': name},
      ]),
    });

    setState(() {
      _files.removeAt(index);
      _fileUploading = false;
    });
  }

  Future<void> _openFileFromUrl(String url, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      final response = await http.get(Uri.parse(url));
      final file = io.File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint('Failed to open file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nie można otwierać plik')));
    }
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _descCtrl.removeListener(_descListener);
    _descDebounce?.cancel();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleCol = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AutoSizeText(
          _customerName,
          style: const TextStyle(color: Colors.black),
          maxLines: 1,
          minFontSize: 8,
        ),
        AutoSizeText(
          _projectName,
          style: TextStyle(color: Colors.red.shade900),
          maxLines: 1,
          minFontSize: 8,
        ),
      ],
    );
    return AppScaffold(
      title: '',
      titleWidget: titleCol,
      centreTitle: true,

      actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0))],

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : DismissKeyboard(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Opis projektu',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.multiline,
                        minLines: 4,
                        maxLines: null,
                        readOnly: !widget.isAdmin,
                        validator: (v) {
                          if (widget.isAdmin &&
                              (v == null || v.trim().isEmpty)) {
                            return 'Wpisz opis';
                          }
                          return null;
                        },
                      ),

                      // gap for files
                      const SizedBox(height: 8),

                      // files
                      _fileUploading
                          ? const Center(child: CircularProgressIndicator())
                          : _files.isEmpty
                          ? GestureDetector(
                              onTap: _pickAndUploadFiles,
                              child: Container(
                                height: 80,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Dotnij aby dodać plik'),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 140,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const ClampingScrollPhysics(),
                                    itemCount: _files.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (ctx, i) {
                                      final file = _files[i];
                                      final name = file['name'] ?? '';
                                      return InkWell(
                                        onTap: () => _openFileFromUrl(
                                          file['url']!,
                                          file['name'] ?? 'plik',
                                        ),

                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Tooltip(
                                                  message: name,
                                                  waitDuration: const Duration(
                                                    milliseconds: 500,
                                                  ),
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              if (widget.isAdmin)
                                                GestureDetector(
                                                  onTap: () => _deleteFile(i),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: Container(
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Colors.red,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            6,
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
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: _pickAndUploadFiles,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.blueAccent,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.blue.withValues(
                                        alpha: 0.05,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.add, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'dodaj pliki',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                      const SizedBox(height: 6),
                      // images
                      _uploading
                          ? const Center(child: CircularProgressIndicator())
                          : _photoUrls.isEmpty
                          ? GestureDetector(
                              onTap: _showPhotoSourceDialog,
                              child: Container(
                                height: 80,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Dotknij aby dodać fotka'),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // unlimited grid that grows with content
                                GridView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6,
                                        childAspectRatio:
                                            2, // rectangular (width is twice height)
                                      ),
                                  itemCount: _photoUrls.length,
                                  itemBuilder: (ctx, i) {
                                    final url = _photoUrls[i];
                                    return GestureDetector(
                                      onTap: () => _openGallery(i),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              url,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (widget.isAdmin)
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () => _deletePhoto(url),
                                                child: Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 12,
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

                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: _showPhotoSourceDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.green),
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.green.withValues(
                                        alpha: 0.05,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.add_a_photo, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'dodaj fotki',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                      const Divider(),

                      // — MAP PREVIEW
                      SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            GoogleMap(
                              onMapCreated: (controller) =>
                                  _mapController = controller,
                              initialCameraPosition: CameraPosition(
                                target:
                                    _location ?? const LatLng(52.237, 21.017),
                                zoom: 14,
                              ),
                              markers: _location == null
                                  ? {}
                                  : {
                                      Marker(
                                        markerId: const MarkerId('projectLoc'),
                                        position: _location!,
                                      ),
                                    },
                              onTap: (pos) async {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLng(pos),
                                );
                                final docRef = FirebaseFirestore.instance
                                    .collection('customers')
                                    .doc(widget.customerId)
                                    .collection('projects')
                                    .doc(widget.projectId);
                                await docRef.set({
                                  'location': GeoPoint(
                                    pos.latitude,
                                    pos.longitude,
                                  ),
                                }, SetOptions(merge: true));
                                final url = Uri.https(
                                  'maps.googleapis.com',
                                  '/maps/api/geocode/json',
                                  {
                                    'latlng':
                                        '${pos.latitude},${pos.longitude}',
                                    'key':
                                        'AIzaSyDkXiS4JP9iySRXxzOiI1oN0_EmI6Tx208',
                                  },
                                );
                                final resp = await http.get(url);
                                final body =
                                    jsonDecode(resp.body)
                                        as Map<String, dynamic>;
                                if (body['status'] == 'OK' &&
                                    (body['results'] as List).isNotEmpty) {
                                  final formatted =
                                      body['results'][0]['formatted_address']
                                          as String;
                                  await docRef.set({
                                    'address': formatted,
                                  }, SetOptions(merge: true));
                                  setState(() => _addressCtrl.text = formatted);
                                }
                              },
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                            ),

                            Positioned(
                              top: 50,
                              left: 1,
                              child: ElevatedButton.icon(
                                // icon: const Icon(
                                //   Icons.map,
                                //   color: Colors.lightBlue,
                                //   size: 20,
                                // ),
                                label: const Text(
                                  'Map',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.9,
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _pickLocation,
                              ),
                            ),

                            Positioned(
                              top: 1,
                              left: 1,
                              child: ElevatedButton.icon(
                                // icon: const Icon(
                                //   Icons.roundabout_left,
                                //   color: Color.fromARGB(255, 5, 190, 11),
                                //   size: 20,
                                // ),
                                label: const Text(
                                  'Jedź',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.9,
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _launchNavigation,
                              ),
                            ),
                          ],
                        ),
                      ),

                      TextFormField(
                        controller: _addressCtrl,
                        decoration: InputDecoration(
                          hintText: 'Nazwa budynku, adres, kod lub URL',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchAddress,
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onFieldSubmitted: (_) => _searchAddress(),
                      ),
                    ],
                  ),
                ),
              ),

              // floatingActionButton: FloatingActionButton(
              //   tooltip: 'Dodaj…',
              //   onPressed: () {
              //     showModalBottomSheet<void>(
              //       context: context,
              //       builder: (ctx) => Column(
              //         mainAxisSize: MainAxisSize.min,
              //         children: [
              //           ListTile(
              //             leading: const Icon(Icons.add_a_photo),
              //             title: const Text('Dodaj fota'),
              //             onTap: () {
              //               Navigator.pop(ctx);
              //               _showPhotoSourceDialog();
              //             },
              //           ),
              //           ListTile(
              //             leading: const Icon(Icons.attach_file),
              //             title: const Text('Dodaj plik'),
              //             onTap: () {
              //               Navigator.pop(ctx);
              //               _pickAndUploadFiles();
              //             },
              //           ),
              //         ],
              //       ),
              //     );
              //   },
              //   child: const Icon(Icons.add),
              // ),

              // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
              // bottomNavigationBar: SafeArea(
              //   child: BottomAppBar(
              //     shape: const CircularNotchedRectangle(),
              //     notchMargin: 6,
              //     child: Padding(
              //       padding: const EdgeInsets.symmetric(horizontal: 32),
              //       child: Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           IconButton(
              //             tooltip: 'Kontakty',
              //             icon: const Icon(Icons.contact_mail_outlined),
              //             onPressed: () => Navigator.of(context).push(
              //               MaterialPageRoute(builder: (_) => ContactsListScreen()),
              //             ),
              //           ),
              //           IconButton(
              //             tooltip: 'Klienci',
              //             icon: const Icon(Icons.people),
              //             onPressed: () => Navigator.of(context).push(
              //               MaterialPageRoute(
              //                 builder: (_) =>
              //                     CustomerListScreen(isAdmin: widget.isAdmin),
              //               ),
              //             ),
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
            ),
    );
  }
}

class _ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final Future<void> Function(String url) onDelete;

  const _ImageGalleryScreen({
    required this.images,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  __ImageGalleryScreenState createState() => __ImageGalleryScreenState();
}

class __ImageGalleryScreenState extends State<_ImageGalleryScreen> {
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
        leading: CloseButton(color: Colors.white),
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
                Navigator.of(context).pop();
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
