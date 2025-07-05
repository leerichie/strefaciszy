import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const LocationPickerScreen({Key? key, this.initialLocation})
    : super(key: key);

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _picked;

  @override
  void initState() {
    super.initState();
    // Default centre Poland
    _picked = widget.initialLocation ?? const LatLng(52.237, 21.017);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miejsce inwestycji:'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Zatwierdź',
            onPressed: () {
              Navigator.of(context).pop(_picked);
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _picked, zoom: 14),
        onTap: (pos) => setState(() => _picked = pos),
        markers: {
          Marker(markerId: const MarkerId('picked'), position: _picked),
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
