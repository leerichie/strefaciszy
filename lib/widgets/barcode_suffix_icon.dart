// lib/widgets/barcode_suffix_icon.dart
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

class BarcodeSuffixIcon extends StatelessWidget {
  const BarcodeSuffixIcon({super.key, required this.onCode});
  final void Function(String code) onCode;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Skanuj kod',
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: () async {
        final code = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const ScanScreen(returnCode: true)),
        );
        if (code != null && code.isNotEmpty) onCode(code);
      },
    );
  }
}
