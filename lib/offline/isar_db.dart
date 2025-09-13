import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strefa_ciszy/offline/models/note_local.dart';
import 'package:strefa_ciszy/offline/models/pending_op.dart';
import 'package:strefa_ciszy/offline/models/photo_local.dart';
import 'package:strefa_ciszy/offline/models/project_item_local.dart';
import 'package:strefa_ciszy/offline/models/project_local.dart';

class IsarDb {
  static Isar? _isar;

  static Future<Isar> instance() async {
    if (_isar != null && _isar!.isOpen) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        ProjectLocalSchema,
        ProjectItemLocalSchema,
        NoteLocalSchema,
        PhotoLocalSchema,
        PendingOpSchema,
      ],
      directory: dir.path,
      inspector: false,
    );
    return _isar!;
  }

  static Future<void> close() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
      _isar = null;
    }
  }
}
