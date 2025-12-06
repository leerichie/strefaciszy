// lib/widgets/chip_contact_role.dart
import 'package:flutter/material.dart';

class ContactRoleChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;

  static const Color _roleColor = Color.fromARGB(255, 78, 103, 79);

  const ContactRoleChip({super.key, required this.label, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: RawChip(
        label: Text(label, overflow: TextOverflow.ellipsis),
        onDeleted: onDeleted,
        backgroundColor: _roleColor,
        selectedColor: _roleColor,
        disabledColor: _roleColor,
        showCheckmark: false,
        pressElevation: 0,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,

        visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

        labelStyle: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        deleteIcon: onDeleted != null
            ? const Icon(Icons.close, size: 13, color: Colors.white)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
