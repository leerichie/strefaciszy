// lib/screens/inventory_list_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/item_detail_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/utils/inventory_sort.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/utils/search_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:strefa_ciszy/widgets/inventory_sort_button.dart';

class InventoryListScreen extends StatefulWidget {
  final bool isAdmin;
  final String? initialSearch;
  final Set<String>? onlyIds;

  const InventoryListScreen({
    super.key,
    required this.isAdmin,
    this.initialSearch,
    this.onlyIds,
  });

  @override
  _InventoryListScreenState createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  String _search = '';
  String _category = '';
  List<String> _categories = [];
  late final TextEditingController _searchController;
  InventorySortField _sortField = InventorySortField.quantity;
  bool _sortAsc = false;

  String? _unitFilter;
  String? _producerFilter;
  List<String> _producers = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch ?? '');
    _search = widget.initialSearch?.trim() ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _search = '';
      _category = '';
      _unitFilter = null;
      _producerFilter = null;
      _sortField = InventorySortField.quantity;
      _sortAsc = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.isAdmin;
    const title = 'Magazyn';

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Skanuj',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
        child: const Icon(Icons.qr_code_scanner, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      centreTitle: true,
      title: title,
      showBackOnWeb: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Wyszukaj…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
              ),

              const SizedBox(width: 8),

              InventorySortMenu(
                sortField: _sortField,
                onSortFieldChanged: (field) {
                  setState(() {
                    _sortField = field;
                  });
                },
                currentProducer: _producerFilter,
                producerOptions: _producers,
                onProducerChanged: (value) {
                  setState(() {
                    _producerFilter = value;
                  });
                },
                currentUnit: _unitFilter,
                unitOptions: const ['szt', 'kpl', 'mb', 'm', 'kg'],
                onUnitChanged: (value) {
                  setState(() {
                    _unitFilter = value;
                  });
                },
                currentCategory: _category.isEmpty ? null : _category,
                categoryOptions: _categories,
                onCategoryChanged: (value) {
                  setState(() {
                    _category = value ?? '';
                  });
                },
              ),

              //  ASC/DESC
              SortDirectionButton(
                ascending: _sortAsc,
                onChanged: (asc) {
                  setState(() {
                    _sortAsc = asc;
                  });
                },
              ),

              IconButton(
                tooltip: 'Resetuj filtr',
                icon: const Icon(Icons.refresh),
                onPressed: _resetFilters,
              ),
            ],
          ),
        ),
      ),

      actions: const [SizedBox(width: 8)],

      body: DismissKeyboard(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<StockItem>>(
                future: ApiService.fetchProducts(
                  search: _search.isNotEmpty ? _search : null,
                  category: null,
                  limit: 200,
                  offset: 0,
                ),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  final allItems = snap.data ?? [];

                  final derivedCategories =
                      allItems
                          .map((item) => item.category.trim())
                          .where((c) => c.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );

                  final derivedProducers =
                      allItems
                          .map((item) => item.producent.trim())
                          .where((p) => p.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!listEquals(_categories, derivedCategories) ||
                        !listEquals(_producers, derivedProducers)) {
                      setState(() {
                        _categories = derivedCategories;
                        _producers = derivedProducers;
                      });
                    }
                  });

                  // onlyIds
                  final afterOnlyIds = widget.onlyIds == null
                      ? allItems
                      : allItems
                            .where((i) => widget.onlyIds!.contains(i.id))
                            .toList();

                  //  text
                  List<StockItem> filtered = _search.isEmpty
                      ? afterOnlyIds
                      : afterOnlyIds.where((item) {
                          return matchesSearch(_search, [
                            item.name,
                            item.producent,
                            item.category.isNotEmpty
                                ? item.category
                                : item.description,
                            item.sku,
                            item.barcode,
                          ]);
                        }).toList();

                  //   PRODUCER
                  if (_producerFilter != null && _producerFilter!.isNotEmpty) {
                    final targetProd = _producerFilter!.toLowerCase().trim();
                    filtered = filtered
                        .where(
                          (item) =>
                              item.producent.toLowerCase().trim() == targetProd,
                        )
                        .toList();
                  }

                  //  CATEGORY
                  if (_category.isNotEmpty) {
                    final targetCat = _category.toLowerCase().trim();
                    filtered = filtered
                        .where(
                          (item) =>
                              item.category.toLowerCase().trim() == targetCat,
                        )
                        .toList();
                  }

                  //  UNIT
                  if (_unitFilter != null && _unitFilter!.isNotEmpty) {
                    final targetUnit = _unitFilter!.toLowerCase().trim();
                    filtered = filtered
                        .where(
                          (item) =>
                              item.unit.toLowerCase().trim() == targetUnit,
                        )
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Nie znaleziono produktów.'),
                    );
                  }

                  final sorted = applyInventorySort(
                    filtered,
                    field: _sortField,
                    ascending: _sortAsc,
                  );

                  return NotificationListener<ScrollNotification>(
                    onNotification: (notif) {
                      if (notif is ScrollStartNotification) {
                        FocusScope.of(context).unfocus();
                      }
                      return false;
                    },
                    child: SelectionArea(
                      child: ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = sorted[i];

                          return ListTile(
                            isThreeLine: true,
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.producent,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'WAPRO id_artykulu: ${item.id}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                ),
                                Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  item.category.isNotEmpty
                                      ? item.category
                                      : item.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${item.quantity}${item.unit.isNotEmpty ? ' ${item.unit}' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: item.quantity <= 0
                                    ? Colors.red
                                    : item.quantity <= 3
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                            trailing: item.imageUrl != null
                                ? SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        item.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 24,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ItemDetailScreen(
                                    itemId: item.id,
                                    isAdmin: widget.isAdmin,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
