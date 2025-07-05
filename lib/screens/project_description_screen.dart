// lib/screens/project_description_screen.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/location_picker_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/services/storage_service.dart';

class ProjectDescriptionScreen extends StatefulWidget {
  final String customerId;
  final String projectId;
  final bool isAdmin;

  const ProjectDescriptionScreen({
    Key? key,
    required this.customerId,
    required this.projectId,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _ProjectDescriptionScreenState createState() =>
      _ProjectDescriptionScreenState();
}

class _ProjectDescriptionScreenState extends State<ProjectDescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  final _addressCtrl = TextEditingController();
  late GoogleMapController _mapController;
  String _customerName = '';
  String _projectName = '';

  LatLng? _location;
  List<String> _photoUrls = [];
  final ImagePicker _picker = ImagePicker();
  List<XFile> _newImages = [];
  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadDescription();
    _loadNames();
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

      _photoUrls = List<String>.from(data['photos'] ?? []);
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ref = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    await ref.update({
      'description': _descCtrl.text.trim(),
      'descriptionUpdatedAt': FieldValue.serverTimestamp(),
    });

    final updateData = <String, dynamic>{
      'description': _descCtrl.text.trim(),
      'descriptionUpdatedAt': FieldValue.serverTimestamp(),
      if (_addressCtrl.text.trim().isNotEmpty)
        'address': _addressCtrl.text.trim(),
      if (_location != null)
        'location': GeoPoint(_location!.latitude, _location!.longitude),
    };

    await ref.update(updateData);

    setState(() => _saving = false);
    Navigator.pop(context);
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
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: _location),
      ),
    );
    if (result != null) {
      setState(() => _location = result);
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(result, 15));

      final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '${result.latitude},${result.longitude}',
        'key': 'AIzaSyACykl4m8C7NUTXfoyQ7PQve-3Zqjxqeoc',
      });
      final resp = await http.get(url);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      String? formatted;
      if (body['status'] == 'OK' && body['results'].isNotEmpty) {
        formatted = body['results'][0]['formatted_address'] as String;
        setState(() => _addressCtrl.text = formatted!);
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie potwierdziles lokalizacji ✓ na mapie!')),
      );
    }
  }

  Future<void> _searchAddress() async {
    final input = _addressCtrl.text.trim();
    if (input.isEmpty) return;

    final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': input,
      'key': 'AIzaSyACykl4m8C7NUTXfoyQ7PQve-3Zqjxqeoc',
    });
    final resp = await http.get(url);
    final map = jsonDecode(resp.body) as Map<String, dynamic>;

    if (map['status'] == 'OK' && (map['results'] as List).isNotEmpty) {
      final loc =
          map['results'][0]['geometry']['location'] as Map<String, dynamic>;
      final newPos = LatLng(loc['lat'] as double, loc['lng'] as double);
      setState(() {
        _location = newPos;
      });
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .update({
            'location': GeoPoint(newPos.latitude, newPos.longitude),
            'address': input,
          });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nie znaleziono miejsca')));
    }
  }

  Future<void> _pickAndUploadPhotos() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null || picked.isEmpty) return;

    setState(() => _uploading = true);

    final docRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    final newUrls = <String>[];

    for (final xfile in picked) {
      final url = await _storageService.uploadProjectFile(
        widget.projectId,
        xfile,
      );
      newUrls.add(url);
    }

    await docRef.update({'photos': FieldValue.arrayUnion(newUrls)});
    setState(() {
      _photoUrls.addAll(newUrls);
      _uploading = false;
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final title = 'INFO: $_customerName – $_projectName';
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              // TextSpan(
              //   text: 'INFO: ',
              //   style: TextStyle(color: Colors.black, fontSize: 16),
              // ),
              TextSpan(
                text: '$_customerName: ',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: _projectName,
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_loading && widget.isAdmin)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _saving ? null : _save,
              tooltip: 'Zapisz opis',
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black,
              child: IconButton(
                icon: const Icon(Icons.home),
                color: Colors.white,
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const MainMenuScreen(role: 'admin'),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      minLines: 6,
                      maxLines: null,
                      readOnly: !widget.isAdmin,
                      validator: (v) {
                        if (widget.isAdmin && (v == null || v.trim().isEmpty)) {
                          return 'Wpisz opis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Text(
                    //   'Miejsce Inwestyji: (dodać pinezka)',
                    //   style: Theme.of(context).textTheme.titleMedium,
                    // ),
                    // const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Szukaj po nazwie budynku albo adres',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchAddress,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (_) => _searchAddress(),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 200,
                      child: _location == null
                          ? const Center(child: Text('Brak lokalizacji'))
                          : GoogleMap(
                              onMapCreated: (c) => _mapController = c,
                              initialCameraPosition: CameraPosition(
                                target: _location!,
                                zoom: 14,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('projectLoc'),
                                  position: _location!,
                                ),
                              },
                              onTap: (pos) async {
                                // 1) Update UI real time
                                setState(() {
                                  _location = pos;
                                  _addressCtrl.text = '';
                                });

                                await FirebaseFirestore.instance
                                    .collection('customers')
                                    .doc(widget.customerId)
                                    .collection('projects')
                                    .doc(widget.projectId)
                                    .update({
                                      'location': GeoPoint(
                                        pos.latitude,
                                        pos.longitude,
                                      ),
                                    });

                                final url = Uri.https(
                                  'maps.googleapis.com',
                                  '/maps/api/geocode/json',
                                  {
                                    'latlng':
                                        '${pos.latitude},${pos.longitude}',
                                    'key':
                                        'AIzaSyACykl4m8C7NUTXfoyQ7PQve-3Zqjxqeoc',
                                  },
                                );
                                final resp = await http.get(url);
                                final body =
                                    jsonDecode(resp.body)
                                        as Map<String, dynamic>;
                                if (body['status'] == 'OK' &&
                                    body['results'].isNotEmpty) {
                                  final formatted =
                                      body['results'][0]['formatted_address']
                                          as String;
                                  setState(() => _addressCtrl.text = formatted);
                                  await FirebaseFirestore.instance
                                      .collection('customers')
                                      .doc(widget.customerId)
                                      .collection('projects')
                                      .doc(widget.projectId)
                                      .update({'address': formatted});
                                }
                              },
                            ),
                    ),

                    TextButton.icon(
                      icon: const Icon(Icons.location_on),
                      label: const Text('Otwieraj i zaznacz pinezka na mapie'),
                      onPressed: _pickLocation,
                    ),

                    // const SizedBox(height: 12),
                    Text(
                      'Foty:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: 100,
                      child: _uploading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  _photoUrls.length + (widget.isAdmin ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (ctx, i) {
                                // Add-photo button at end
                                if (i == _photoUrls.length && widget.isAdmin) {
                                  return GestureDetector(
                                    onTap: _pickAndUploadPhotos,
                                    child: Container(
                                      width: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo,
                                        size: 32,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  );
                                }

                                final url = _photoUrls[i];
                                return Stack(
                                  children: [
                                    // Thumbnail tappable to open gallery
                                    GestureDetector(
                                      onTap: () => _openGallery(i),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),

                                    // Delete “×” for admins on thumbnail
                                    if (widget.isAdmin)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _deletePhoto(url),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

      floatingActionButton: FloatingActionButton(
        tooltip: 'Dodaj fotka',
        onPressed: _pickAndUploadPhotos,
        child: const Icon(Icons.add_photo_alternate_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Kontakty',
                  icon: const Icon(Icons.contact_mail_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ContactsListScreen()),
                  ),
                ),
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.people),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomerListScreen(isAdmin: widget.isAdmin),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CloseButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final url = widget.images[_currentIndex];
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
