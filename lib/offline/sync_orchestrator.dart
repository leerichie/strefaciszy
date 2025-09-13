// lib/offline/sync_orchestrator.dart
import 'dart:async';

import 'sync_service.dart';

class SyncOrchestrator {
  final SyncService _sync;
  Timer? _timer;
  bool _busy = false;

  int _intervalSec = 5;
  final int _minSec = 5;
  final int _maxSec = 60;

  SyncOrchestrator._(this._sync);

  static Future<SyncOrchestrator> create() async {
    final sync = await SyncService.create();
    return SyncOrchestrator._(sync);
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: _intervalSec), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> triggerNow() async => _tick(force: true);

  Future<void> _tick({bool force = false}) async {
    if (_busy && !force) return;
    _busy = true;
    try {
      final processed = await _sync.runOnce(batchSize: 25);
      if (processed > 0) {
        _intervalSec = _minSec;
      } else {
        _intervalSec = (_intervalSec * 2).clamp(_minSec, _maxSec);
      }
      if (_timer != null) {
        _timer!.cancel();
        _timer = Timer.periodic(
          Duration(seconds: _intervalSec),
          (_) => _tick(),
        );
      }
    } finally {
      _busy = false;
    }
  }
}
