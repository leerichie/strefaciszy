import 'package:isar/isar.dart';

import 'project_local.dart';

part 'note_local.g.dart';

@collection
class NoteLocal {
  Id id;
  String noteId;
  String projectId;
  String text;

  DateTime createdAtLocal;
  String? serverId;

  @enumerated
  SyncState syncState;

  NoteLocal({
    this.id = Isar.autoIncrement,
    required this.noteId,
    required this.projectId,
    required this.text,
    this.serverId,
    this.syncState = SyncState.synced,
  }) : createdAtLocal = DateTime.now();
}
