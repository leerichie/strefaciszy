import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String customerId;
  final String projectId;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    required this.customerId,
    required this.projectId,
  });

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation ?? const LatLng(52.237, 21.017);
  }

  Future<void> _saveLocationAndAddress(LatLng pos) async {
    final docRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    await docRef.set({
      'location': GeoPoint(pos.latitude, pos.longitude),
    }, SetOptions(merge: true));

    final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '${pos.latitude},${pos.longitude}',
      'key': 'AIzaSyACykl4m8C7NUTXfoyQ7PQve-3Zqjxqeoc',
    });
    final resp = await http.get(url);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] == 'OK' && (body['results'] as List).isNotEmpty) {
      final formatted = body['results'][0]['formatted_address'] as String;
      await docRef.set({'address': formatted}, SetOptions(merge: true));
    }
  }

  Future<void> _launchNavigation() async {
    final lat = _picked.latitude;
    final lng = _picked.longitude;

    final googleNav = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final appleNav = Uri.parse('maps://?daddr=$lat,$lng&dirflg=d');
    final webFallback = Uri.parse(
      Theme.of(context).platform == TargetPlatform.android
          ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
          : 'https://maps.apple.com/?daddr=$lat,$lng',
    );

    if (await canLaunchUrl(
      Theme.of(context).platform == TargetPlatform.android
          ? googleNav
          : appleNav,
    )) {
      await launchUrl(
        Theme.of(context).platform == TargetPlatform.android
            ? googleNav
            : appleNav,
      );
    } else {
      await launchUrl(webFallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Miejsce inwestycji';
    return AppScaffold(
      showBackOnWeb: true,
      title: title,
      centreTitle: true,
      body: DismissKeyboard(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _picked,
                    zoom: 14,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _picked,
                      draggable: true,
                      onDragEnd: (pos) {
                        setState(() => _picked = pos);
                        _saveLocationAndAddress(pos);
                      },
                    ),
                  },
                  onTap: (pos) {
                    setState(() => _picked = pos);
                    _saveLocationAndAddress(pos);
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.directions, color: Colors.red),
                  label: const Text(
                    'Jedziemy!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.fromHeight(48),
                  ),
                  onPressed: _launchNavigation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
