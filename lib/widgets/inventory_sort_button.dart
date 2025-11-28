// lib/widgets/inventory_sort_button.dart
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/utils/inventory_sort.dart';

class SortDirectionButton extends StatelessWidget {
  final bool ascending;
  final ValueChanged<bool> onChanged;

  const SortDirectionButton({
    super.key,
    required this.ascending,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: ascending ? 'Rosnąco' : 'Malejąco',
      icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
      onPressed: () => onChanged(!ascending),
    );
  }
}

class InventorySortMenu extends StatelessWidget {
  final InventorySortField sortField;
  final ValueChanged<InventorySortField> onSortFieldChanged;

  final String? currentProducer;
  final List<String> producerOptions;
  final ValueChanged<String?> onProducerChanged;

  final String? currentUnit;
  final List<String> unitOptions;
  final ValueChanged<String?> onUnitChanged;

  final String? currentCategory;
  final List<String> categoryOptions;
  final ValueChanged<String?> onCategoryChanged;
  const InventorySortMenu({
    super.key,
    required this.sortField,
    required this.onSortFieldChanged,
    required this.currentProducer,
    required this.producerOptions,
    required this.onProducerChanged,
    required this.currentUnit,
    required this.unitOptions,
    required this.onUnitChanged,
    required this.currentCategory,
    required this.categoryOptions,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    const double submenuMinWidth = 220;
    final producers =
        producerOptions.where((p) => p.trim().isNotEmpty).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final cats =
        categoryOptions.where((c) => c.trim().isNotEmpty).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final units = unitOptions;

    return MenuAnchor(
      builder: (context, controller, child) {
        return IconButton(
          tooltip: 'Sortowanie / Filtry',
          icon: const Icon(Icons.sort),
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
      menuChildren: [
        // sort
        SubmenuButton(
          menuChildren: [
            for (final field in InventorySortField.values)
              MenuItemButton(
                onPressed: () => onSortFieldChanged(field),
                child: Row(
                  children: [
                    if (field == sortField) ...[
                      const Icon(
                        Icons.check,
                        size: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 38, 223, 44),
                      ),
                      const SizedBox(width: 8),
                    ] else
                      const SizedBox(width: 24),
                    Text(inventorySortFieldLabel(field)),
                  ],
                ),
              ),
          ],
          child: const Row(
            children: [
              Text('Sortuj wg'),
              SizedBox(width: 4),
              // Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),

        const Divider(),

        // producer
        SubmenuButton(
          menuChildren: [
            SizedBox(
              width: submenuMinWidth,
              child: MenuItemButton(
                onPressed: () => onProducerChanged(null),
                child: Row(
                  children: [
                    if (currentProducer == null ||
                        currentProducer!.isEmpty) ...[
                      const Icon(
                        Icons.check,
                        size: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 38, 223, 44),
                      ),
                      const SizedBox(width: 8),
                    ] else
                      const SizedBox(width: 24),
                    const Text('Wszyscy'),
                  ],
                ),
              ),
            ),
            for (final p in producers)
              SizedBox(
                width: submenuMinWidth,
                child: MenuItemButton(
                  onPressed: () => onProducerChanged(p),
                  child: Row(
                    children: [
                      if (currentProducer != null &&
                          currentProducer!.toLowerCase().trim() ==
                              p.toLowerCase().trim()) ...[
                        const Icon(
                          Icons.check,
                          size: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 38, 223, 44),
                        ),
                        const SizedBox(width: 8),
                      ] else
                        const SizedBox(width: 24),
                      Text(p),
                    ],
                  ),
                ),
              ),
          ],
          child: const Row(children: [Text('Producent'), SizedBox(width: 4)]),
        ),
        const Divider(),

        // unit
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: () => onUnitChanged(null),
              child: Row(
                children: [
                  if (currentUnit == null || currentUnit!.isEmpty) ...[
                    const Icon(
                      Icons.check,
                      size: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 38, 223, 44),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 24),
                  const Text('wszystko'),
                ],
              ),
            ),
            for (final u in units)
              MenuItemButton(
                onPressed: () => onUnitChanged(u),
                child: Row(
                  children: [
                    if (currentUnit != null &&
                        currentUnit!.toLowerCase().trim() ==
                            u.toLowerCase().trim()) ...[
                      const Icon(
                        Icons.check,
                        size: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 38, 223, 44),
                      ),
                      const SizedBox(width: 8),
                    ] else
                      const SizedBox(width: 24),
                    Text(u),
                  ],
                ),
              ),
          ],
          child: const Row(children: [Text('Jednostka'), SizedBox(width: 4)]),
        ),

        const Divider(),

        // cat.
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: () => onCategoryChanged(null),
              child: Row(
                children: [
                  if (currentCategory == null || currentCategory!.isEmpty) ...[
                    const Icon(
                      Icons.check,
                      size: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 38, 223, 44),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 24),
                  const Text('wszystko'),
                ],
              ),
            ),
            for (final cat in cats)
              MenuItemButton(
                onPressed: () => onCategoryChanged(cat),
                child: Row(
                  children: [
                    if (currentCategory != null &&
                        currentCategory!.toLowerCase().trim() ==
                            cat.toLowerCase().trim()) ...[
                      const Icon(
                        Icons.check,
                        size: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 38, 223, 44),
                      ),
                      const SizedBox(width: 8),
                    ] else
                      const SizedBox(width: 24),
                    Text(cat),
                  ],
                ),
              ),
          ],
          child: const Row(children: [Text('Kategoria'), SizedBox(width: 4)]),
        ),
      ],
    );
  }
}
