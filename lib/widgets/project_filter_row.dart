import 'package:flutter/material.dart';

class ProjectFilterRow extends StatelessWidget {
  final bool sortIsOriginal;
  final bool sortIsDateNewest;
  final bool sortIsType;

  final bool isAdmin;
  final bool selectionMode;
  final bool hasItems;

  final VoidCallback onReset;
  final VoidCallback onSortOriginal;
  final VoidCallback onSortDateNewest;
  final VoidCallback onSortType;
  final VoidCallback? onMove;

  final VoidCallback? onClear;

  final VoidCallback onAdd;

  const ProjectFilterRow({
    super.key,
    required this.sortIsOriginal,
    required this.sortIsDateNewest,
    required this.sortIsType,
    required this.isAdmin,
    required this.selectionMode,
    required this.hasItems,
    required this.onReset,
    required this.onSortOriginal,
    required this.onSortDateNewest,
    required this.onSortType,
    required this.onClear,
    required this.onAdd,
    this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // REFRESH / ORIGINAL
        ChoiceChip(
          label: const Icon(Icons.refresh),
          selected: sortIsOriginal,
          onSelected: (_) => onReset(),
        ),

        // DATE
        ChoiceChip(
          label: const Text('Date'),
          selected: sortIsDateNewest,
          onSelected: (_) => onSortDateNewest(),
        ),

        // TYPE
        ChoiceChip(
          label: const Text('Typ'),
          selected: sortIsType,
          onSelected: (_) => onSortType(),
        ),

        // DELETE (admin only)
        if (isAdmin)
          ChoiceChip(
            label: Text(
              'Usuń',
              style: TextStyle(
                color: selectionMode ? Colors.red : Colors.red.shade700,
              ),
            ),
            labelPadding: EdgeInsets.zero,
            selected: selectionMode,
            onSelected: (!hasItems || onClear == null)
                ? null
                : (_) => onClear!(),
            backgroundColor: Colors.transparent,
            selectedColor: Colors.red.withValues(alpha: 0.08),
            side: BorderSide(
              color: selectionMode ? Colors.red : Colors.grey.shade400,
            ),
          ),

        // ADD
        ChoiceChip(
          label: Text('Dodaj', style: TextStyle(color: Colors.green.shade800)),
          labelPadding: EdgeInsets.zero,
          selected: false,
          onSelected: (_) => onAdd(),
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: Colors.blueAccent),
        ),
        // MOVE
        if (isAdmin && onMove != null)
          ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.drive_file_move, size: 18),
                SizedBox(width: 6),
                Text('Przenieś'),
              ],
            ),
            labelPadding: EdgeInsets.zero,
            selected: false,
            onSelected: (!hasItems) ? null : (_) => onMove!(),
            backgroundColor: Colors.transparent,
            side: BorderSide(color: Colors.grey.shade400),
          ),
      ],
    );
  }
}
