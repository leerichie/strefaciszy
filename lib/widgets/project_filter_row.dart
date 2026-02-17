import 'package:flutter/material.dart';

enum ProjectActionMode { none, delete, move }

class ProjectFilterRow extends StatelessWidget {
  final bool sortIsOriginal;
  final bool sortIsDateNewest;
  final bool sortIsType;

  final bool isAdmin;
  final ProjectActionMode actionMode;
  final bool hasItems;

  final VoidCallback onReset;
  final VoidCallback onSortOriginal;
  final VoidCallback onSortDateNewest;
  final VoidCallback onSortType;
  final VoidCallback? onMove;

  final VoidCallback? onClear;

  final VoidCallback? onAdd;

  const ProjectFilterRow({
    super.key,
    required this.sortIsOriginal,
    required this.sortIsDateNewest,
    required this.sortIsType,
    required this.isAdmin,
    required this.actionMode,
    required this.hasItems,
    required this.onReset,
    required this.onSortOriginal,
    required this.onSortDateNewest,
    required this.onSortType,
    required this.onClear,
    this.onAdd,
    this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor(bool selected, Color active) =>
        selected ? active : Colors.grey.shade700;

    final canAdd = isAdmin && onAdd != null;

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // RESET / ORIGINAL
        ChoiceChip(
          label: Icon(
            Icons.refresh,
            color: iconColor(sortIsOriginal, Colors.blue),
          ),
          selected: sortIsOriginal,
          selectedColor: Colors.blue.withValues(alpha: 0.12),
          onSelected: (_) => onReset(),
        ),

        // DATE
        ChoiceChip(
          label: Text(
            'Date',
            style: TextStyle(
              color: sortIsDateNewest ? Colors.blue : Colors.grey.shade800,
            ),
          ),
          selected: sortIsDateNewest,
          selectedColor: Colors.blue.withValues(alpha: 0.12),
          onSelected: (_) => onSortDateNewest(),
        ),

        // TYPE
        ChoiceChip(
          label: Text(
            'Typ',
            style: TextStyle(
              color: sortIsType ? Colors.blue : Colors.grey.shade800,
            ),
          ),
          selected: sortIsType,
          selectedColor: Colors.blue.withValues(alpha: 0.12),
          onSelected: (_) => onSortType(),
        ),

        // DELETE (admin)
        if (isAdmin)
          ChoiceChip(
            label: Icon(
              Icons.delete,
              size: 18,
              color: iconColor(
                actionMode == ProjectActionMode.delete,
                Colors.red,
              ),
            ),
            labelPadding: EdgeInsets.zero,
            selected: actionMode == ProjectActionMode.delete,
            onSelected: (!hasItems || onClear == null)
                ? null
                : (_) => onClear!(),
            backgroundColor: Colors.transparent,
            selectedColor: Colors.red.withValues(alpha: 0.10),
            side: BorderSide(
              color: (actionMode == ProjectActionMode.delete)
                  ? Colors.red
                  : Colors.grey.shade400,
            ),
          ),

        // ADD (grey + disabled when onAdd == null)
        ChoiceChip(
          label: Icon(
            Icons.add,
            size: 18,
            color: canAdd ? Colors.blue : Colors.grey.shade500,
          ),
          labelPadding: EdgeInsets.zero,
          selected: false,
          onSelected: onAdd == null ? null : (_) => onAdd!(),
          backgroundColor: Colors.transparent,
          side: BorderSide(
            color: canAdd ? Colors.blueAccent : Colors.grey.shade400,
          ),
        ),

        // MOVE (admin)
        if (isAdmin && onMove != null)
          ChoiceChip(
            label: Icon(
              Icons.drive_file_move,
              size: 18,
              color: iconColor(
                actionMode == ProjectActionMode.move,
                Colors.purple,
              ),
            ),
            labelPadding: EdgeInsets.zero,
            selected: actionMode == ProjectActionMode.move,
            onSelected: (!hasItems) ? null : (_) => onMove!(),
            backgroundColor: Colors.transparent,
            selectedColor: Colors.purple.withValues(alpha: 0.10),
            side: BorderSide(
              color: (actionMode == ProjectActionMode.move)
                  ? Colors.purple
                  : Colors.grey.shade400,
            ),
          ),
      ],
    );
  }
}
