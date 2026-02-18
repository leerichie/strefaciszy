// services/share_incoming_service.dart

import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedIncomingService {
  SharedIncomingService._();
  static final SharedIncomingService instance = SharedIncomingService._();

  final ReceiveSharingIntent _receiver = ReceiveSharingIntent.instance;

  StreamSubscription<List<SharedMediaFile>>? _sub;

  List<SharedMediaFile> _files = [];
  List<SharedMediaFile> get files => List.unmodifiable(_files);
  bool get hasFiles => _files.isNotEmpty;

  Future<void> init() async {
    try {
      final initial = await _receiver.getInitialMedia();
      if (initial.isNotEmpty) {
        _files = initial;
      }

      _sub?.cancel();
      _sub = _receiver.getMediaStream().listen((value) {
        if (value.isNotEmpty) {
          _files = value;
        }
      });
    } catch (_) {}
  }

  void clear() {
    _files = [];
    _receiver.reset();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
