class RWDocument {
  final String id;
  final String projectId;
  final String projectName;
  final String createdBy;
  final DateTime createdAt;
  final String type; // 'RW' or 'MM'
  final List<Map<String, dynamic>> items;

  RWDocument({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.createdBy,
    required this.createdAt,
    required this.type,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'projectName': projectName,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'items': items,
    };
  }
}
