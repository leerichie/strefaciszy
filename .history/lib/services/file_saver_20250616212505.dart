// lib/services/file_saver.dart

// Exports the correct implementation depending on platform
export 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart';
