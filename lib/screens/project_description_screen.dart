// lib/screens/project_description_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:strefa_ciszy/screens/location_picker_screen.dart';
import 'package:strefa_ciszy/services/one_drive_link.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:strefa_ciszy/widgets/one_drive_link_button.dart';
import 'package:strefa_ciszy/widgets/project_files_section.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<Map<String, String>> _initialFiles = [];
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  bool _loading = true;
  final _addressCtrl = TextEditingController();
  GoogleMapController? _mapController;
  String _customerName = '';
  String _projectName = '';

  LatLng? _location;
  List<String> _photoUrls = [];
  final ImagePicker _picker = ImagePicker();
  Timer? _descDebounce;
  late final VoidCallback _descListener;
  String? _oneDriveUrl;
  bool _uploading = false;

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

  Future<void> _onOneDriveLinkPressed() async {
    final controller = TextEditingController(text: _oneDriveUrl ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Link do OneDrive'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anuluj'),
            ),
            if ((controller.text.trim().isNotEmpty) ||
                ((_oneDriveUrl ?? '').trim().isNotEmpty))
              TextButton(
                onPressed: () async {
                  final url = controller.text.trim().isEmpty
                      ? (_oneDriveUrl ?? '').trim()
                      : controller.text.trim();

                  if (url.isEmpty) return;

                  try {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nie można otworzyć linku'),
                        ),
                      );
                    }
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nieprawidłowy adres URL')),
                    );
                  }
                },
                child: const Text('Otwórz'),
              ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();

                try {
                  await OneDriveLink.setOneDriveUrl(
                    widget.customerId,
                    widget.projectId,
                    text.isEmpty ? null : text,
                  );
                  setState(() {
                    _oneDriveUrl = text.isEmpty ? null : text;
                  });
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        text.isEmpty
                            ? 'Link OneDrive usunięty'
                            : 'Link OneDrive zapisany',
                      ),
                    ),
                  );
                } catch (e) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nie udało się zapisać linku'),
                    ),
                  );
                }
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );
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

  String _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return url;
    final lastSeg = uri.pathSegments.last;
    final decoded = Uri.decodeComponent(lastSeg);
    final parts = decoded.split('/');

    return parts.isNotEmpty ? parts.last : decoded;
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
      // DESCRIPTION
      final desc =
          (data['description'] ?? data['desc'] ?? data['projectDescription']);
      if (desc is String) {
        _descCtrl.text = desc;
      }

      // ADDRESS & LOCATION
      if (data['address'] is String) {
        _addressCtrl.text = data['address'] as String;
      }
      if (data['location'] is GeoPoint) {
        final gp = data['location'] as GeoPoint;
        _location = LatLng(gp.latitude, gp.longitude);
      }

      //   RAW PHOTOS
      final rawPhotos = data['photos'];
      List<String> photoUrls = [];
      if (rawPhotos is List) {
        photoUrls = rawPhotos.whereType<String>().toList();
      }
      _photoUrls = photoUrls;

      // FILES
      final rawFiles = data['files'];
      final List<Map<String, String>> initialFiles = [];

      if (rawFiles is List) {
        for (final e in rawFiles) {
          if (e is Map) {
            final url = e['url'];
            final name = e['name'];
            if (url is String && url.isNotEmpty && name is String) {
              initialFiles.add({'url': url, 'name': name});
            }
          }
        }
      }

      // merge old files and phots
      final existingUrls = initialFiles
          .map((m) => m['url'])
          .whereType<String>()
          .toSet();

      for (final url in photoUrls) {
        if (url.isEmpty || existingUrls.contains(url)) continue;

        final name = _fileNameFromUrl(url);
        initialFiles.add({'url': url, 'name': name});
      }

      _initialFiles = initialFiles;

      // BACKWARD comp.
      if (initialFiles.isEmpty && photoUrls.isNotEmpty) {
        for (final url in photoUrls) {
          if (url.isEmpty) continue;
          final uri = Uri.tryParse(url);
          final last = uri?.pathSegments.isNotEmpty == true
              ? uri!.pathSegments.last
              : url;
          final name = last.split('?').first;
          initialFiles.add({'url': url, 'name': name});
        }
      }

      _initialFiles = initialFiles;

      // OneDrive
      final oneDrive = data['oneDriveUrl'];
      if (oneDrive is String && oneDrive.trim().isNotEmpty) {
        _oneDriveUrl = oneDrive.trim();
      } else {
        _oneDriveUrl = null;
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
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

    final googleNavUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleMapsWebUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

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
        debugPrint('Failed to read "${xfile.name}": $e');
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
        debugPrint('Upload failed for $fileName: $e');
      }
    }

    if (newUrls.isNotEmpty) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .collection('projects')
            .doc(widget.projectId);

        final newFileMaps = newUrls.map((url) {
          final name = _fileNameFromUrl(url);
          return {'url': url, 'name': name};
        }).toList();

        await docRef.update({
          'photos': FieldValue.arrayUnion(newUrls),
          'files': FieldValue.arrayUnion(newFileMaps),
        });

        setState(() {
          _photoUrls.addAll(newUrls);
          _initialFiles.addAll(newFileMaps);
        });
      } catch (e) {
        debugPrint('Firestore update error → $e');
      }
    }

    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _openOneDriveLink() async {
    final url = _oneDriveUrl?.trim();
    if (url == null || url.isEmpty) {
      await _editOneDriveLink();
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie można otworzyć linku')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nieprawidłowy adres URL')));
    }
  }

  Future<void> _editOneDriveLink() async {
    final controller = TextEditingController(text: _oneDriveUrl ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Link do folderu OneDrive'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL folderu',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();

                try {
                  await OneDriveLink.setOneDriveUrl(
                    widget.customerId,
                    widget.projectId,
                    text.isEmpty ? null : text,
                  );
                  setState(() {
                    _oneDriveUrl = text.isEmpty ? null : text;
                  });
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        text.isEmpty
                            ? 'Link OneDrive usunięty'
                            : 'Link OneDrive zapisany',
                      ),
                    ),
                  );
                } catch (e) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nie udało sie zapisać')),
                  );
                }
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );
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
      showBackOnWeb: true,
      titleWidget: titleCol,
      centreTitle: true,

      actions: [
        OneDriveLinkButton(
          url: _oneDriveUrl,
          onTap: _openOneDriveLink,
          onLongPress: _editOneDriveLink,
        ),
        const SizedBox(width: 4),
      ],

      // actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0))],
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

                      const SizedBox(height: 8),

                      // files
                      ProjectFilesSection(
                        customerId: widget.customerId,
                        projectId: widget.projectId,
                        isAdmin: widget.isAdmin,
                        initialFiles: _initialFiles,
                      ),

                      const Divider(),

                      // — MAP
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
            ),
    );
  }
}
