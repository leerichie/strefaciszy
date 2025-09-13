import 'package:isar/isar.dart';

import 'project_local.dart';

part 'photo_local.g.dart';

@collection
class PhotoLocal {
  Id id;
  String photoId;
  String projectId;

  String localPath;
  String? thumbPath;
  String? cloudUrl;

  DateTime createdAtLocal;

  @enumerated
  SyncState syncState;

  PhotoLocal({
    this.id = Isar.autoIncrement,
    required this.photoId,
    required this.projectId,
    required this.localPath,
    this.thumbPath,
    this.cloudUrl,
    DateTime? createdAtLocal,
    this.syncState = SyncState.localOnly,
  }) : createdAtLocal = createdAtLocal ?? DateTime.now();
}
