// lib/widgets/chip_project.dart
import 'package:flutter/material.dart';

class ProjectChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;

  static const Color _projectColor = Colors.blueAccent;

  const ProjectChip({super.key, required this.label, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RawChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      onDeleted: onDeleted,
      backgroundColor: _projectColor,
      selectedColor: _projectColor,
      disabledColor: _projectColor,
      showCheckmark: false,
      pressElevation: 0,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      deleteIcon: onDeleted != null
          ? const Icon(Icons.close, size: 14, color: Colors.white)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
