// lib/services/file_saver.dart

// Conditionally re-export the proper implementation:
export 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart';
