// No-op stub used on web so Isar code isn't pulled into the build.
class SyncOrchestrator {
  static Future<SyncOrchestrator> create() async => SyncOrchestrator();
  void start() {}
  void stop() {}
  Future<void> triggerNow() async {}
}
