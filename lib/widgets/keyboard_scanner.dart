// lib/widgets/keyboard_scanner.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef ScanHandler = void Function(String code);

class KeyboardScanner extends StatefulWidget {
  final ScanHandler onScan;
  final String hint;
  const KeyboardScanner({
    super.key,
    required this.onScan,
    this.hint = 'Zeskanuj kod…',
  });

  @override
  State<KeyboardScanner> createState() => _KeyboardScannerState();
}

class _KeyboardScannerState extends State<KeyboardScanner> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  bool get _isPc =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;
    widget.onScan(code);
    _ctrl.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPc) return const SizedBox.shrink();

    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      autofocus: true,
      decoration: InputDecoration(
        labelText: widget.hint,
        prefixIcon: const Icon(Icons.qr_code_scanner),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onSubmitted: _submit,

      textInputAction: TextInputAction.done,
    );
  }
}
