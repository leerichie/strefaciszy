// lib/screens/inventory_list_screen.dart

import 'package:flutter/material.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/item_detail_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/utils/category_filter.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/utils/search_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch ?? '');
    _search = widget.initialSearch?.trim() ?? '';

    ApiService.fetchCategories()
        .then((cats) {
          if (!mounted) return;
          final clean = CategoryFilter.buildDropdownCategories(cats);
          setState(() => _categories = clean);
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _categories = []);
        });
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
              IconButton(
                tooltip: 'Resetuj filtr',
                icon: const Icon(Icons.refresh),
                onPressed: _resetFilters,
              ),
            ],
          ),
        ),
      ),
      actions: const [Padding(padding: EdgeInsets.symmetric(horizontal: 8.0))],
      body: DismissKeyboard(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 12),
            //   child: DropdownButtonFormField<String>(
            //     decoration: InputDecoration(
            //       labelText: 'Kategoria',
            //       border: OutlineInputBorder(
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //       isDense: true,
            //     ),
            //     value: _category.isEmpty ? null : _category,
            //     items: [
            //       const DropdownMenuItem(value: '', child: Text('Wszystko')),
            //       ..._categories.map((cat) {
            //         if (cat.isEmpty) {
            //           return const DropdownMenuItem(value: '', child: Text(''));
            //         }
            //         final label = cat[0].toUpperCase() + cat.substring(1);
            //         return DropdownMenuItem(value: cat, child: Text(label));
            //       }),
            //     ],
            //     onChanged: (v) => setState(() => _category = v ?? ''),
            //   ),
            // ),
            // const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<StockItem>>(
                future: ApiService.fetchProducts(
                  search: _search.isNotEmpty ? _search : null,
                  category: _category.isNotEmpty ? _category : null,
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

                  final afterOnlyIds = widget.onlyIds == null
                      ? allItems
                      : allItems
                            .where((i) => widget.onlyIds!.contains(i.id))
                            .toList();

                  final filtered = _search.isEmpty
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

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Nie znaleziono produktów.'),
                    );
                  }

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
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
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
