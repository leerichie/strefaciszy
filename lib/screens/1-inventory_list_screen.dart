// // lib/screens/inventory_list_screen.dart

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:strefa_ciszy/models/stock_item.dart';
// import 'package:strefa_ciszy/screens/add_item_screen.dart';
// import 'package:strefa_ciszy/screens/item_detail_screen.dart';
// import 'package:strefa_ciszy/utils/keyboard_utils.dart';
// import 'package:strefa_ciszy/utils/search_utils.dart';
// import 'package:strefa_ciszy/widgets/app_scaffold.dart';

// class InventoryListScreen extends StatefulWidget {
//   final bool isAdmin;
//   final String? initialSearch;
//   final Set<String>? onlyIds;
//   const InventoryListScreen({
//     super.key,
//     required this.isAdmin,
//     this.initialSearch,
//     this.onlyIds,
//   });

//   @override
//   _InventoryListScreenState createState() => _InventoryListScreenState();
// }

// class _InventoryListScreenState extends State<InventoryListScreen> {
//   String _search = '';
//   String _category = '';
//   List<String> _categories = [];
//   late final TextEditingController _searchController;
//   late final StreamSubscription<QuerySnapshot> _catSub;

//   @override
//   void initState() {
//     super.initState();
//     _searchController = TextEditingController(text: widget.initialSearch ?? '');
//     _search = widget.initialSearch?.trim() ?? '';
//     _catSub = FirebaseFirestore.instance
//         .collection('categories')
//         .orderBy('name')
//         .snapshots()
//         .listen((snap) {
//           setState(() {
//             _categories = snap.docs.map((d) => d['name'] as String).toList();
//           });
//         });
//   }

//   @override
//   void dispose() {
//     _catSub.cancel();
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _resetFilters() {
//     FocusScope.of(context).unfocus();
//     setState(() {
//       _searchController.clear();
//       _search = '';
//       _category = '';
//     });
//   }

//   Query<StockItem> get _stockQuery {
//     Query<Map<String, dynamic>> base = FirebaseFirestore.instance.collection(
//       'stock_items',
//     );

//     if (_category.isNotEmpty) {
//       base = base.where('category', isEqualTo: _category);
//     }

//     base = base.orderBy('name');

//     return base.withConverter<StockItem>(
//       fromFirestore: (snap, _) => StockItem.fromMap(snap.data()!, snap.id),
//       toFirestore: (item, _) => item.toMap(),
//     );
//   }

//   Widget _buildCategoryChip(String? value, String label) {
//     final selected = (value ?? '') == _category;
//     return Padding(
//       padding: const EdgeInsets.only(right: 8),
//       child: ChoiceChip(
//         label: Text(label),
//         selected: selected,
//         onSelected: (_) => setState(() => _category = value ?? ''),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isAdmin = widget.isAdmin;
//     final title = 'Magazyn';
//     return AppScaffold(
//       floatingActionButton: isAdmin
//           ? FloatingActionButton(
//               onPressed: () => Navigator.of(
//                 context,
//               ).push(MaterialPageRoute(builder: (_) => const AddItemScreen())),
//               tooltip: 'Dodaj stock',
//               child: const Icon(Icons.add),
//             )
//           : null,
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
//       centreTitle: true,
//       title: title,
//       bottom: PreferredSize(
//         preferredSize: const Size.fromHeight(56),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           child: Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _searchController,
//                   decoration: InputDecoration(
//                     hintText: 'Wyszukaj…',
//                     prefixIcon: const Icon(Icons.search),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     isDense: true,
//                   ),
//                   onChanged: (v) => setState(() => _search = v.trim()),
//                   textInputAction: TextInputAction.search,
//                   onSubmitted: (_) => FocusScope.of(context).unfocus(),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               IconButton(
//                 tooltip: 'Resetuj filtr',
//                 icon: const Icon(Icons.refresh),
//                 onPressed: _resetFilters,
//               ),
//             ],
//           ),
//         ),
//       ),
//       actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0))],

//       body: DismissKeyboard(
//         child: Column(
//           children: [
//             const SizedBox(height: 8),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child: DropdownButtonFormField<String>(
//                 decoration: InputDecoration(
//                   labelText: 'Kategoria',
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   isDense: true,
//                 ),
//                 value: _category.isEmpty ? null : _category,
//                 items: [
//                   const DropdownMenuItem(value: '', child: Text('Wszystko')),
//                   ..._categories.map((cat) {
//                     final label = cat[0].toUpperCase() + cat.substring(1);
//                     return DropdownMenuItem(value: cat, child: Text(label));
//                   }),
//                 ],
//                 onChanged: (v) => setState(() {
//                   _category = v ?? '';
//                 }),
//               ),
//             ),
//             const SizedBox(height: 8),

//             Expanded(
//               child: StreamBuilder<QuerySnapshot<StockItem>>(
//                 stream: _stockQuery.snapshots(),
//                 builder: (ctx, snap) {
//                   if (snap.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator());
//                   }
//                   if (snap.hasError) {
//                     return Center(child: Text('Error: ${snap.error}'));
//                   }

//                   final allItems = snap.data!.docs
//                       .map((d) => d.data())
//                       .toList();

//                   final preFiltered = widget.onlyIds == null
//                       ? allItems
//                       : allItems
//                             .where((i) => widget.onlyIds!.contains(i.id))
//                             .toList();

//                   final filtered = _search.isEmpty
//                       ? preFiltered
//                       : preFiltered.where((item) {
//                           return matchesSearch(_search, [
//                             item.name,
//                             item.producent,
//                             item.description,
//                             item.sku,
//                             item.barcode,
//                           ]);
//                         }).toList();

//                   if (filtered.isEmpty) {
//                     return const Center(
//                       child: Text('Nie znaleziono produktów.'),
//                     );
//                   }

//                   return NotificationListener<ScrollNotification>(
//                     onNotification: (notif) {
//                       if (notif is ScrollStartNotification) {
//                         FocusScope.of(context).unfocus();
//                       }
//                       return false;
//                     },
//                     child: ListView.separated(
//                       keyboardDismissBehavior:
//                           ScrollViewKeyboardDismissBehavior.onDrag,
//                       itemCount: filtered.length,
//                       separatorBuilder: (_, __) => const Divider(height: 1),
//                       itemBuilder: (ctx, i) {
//                         final item = filtered[i];
//                         return ListTile(
//                           isThreeLine: true,
//                           title: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 item.producent ?? '',
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               Text(
//                                 item.name,
//                                 style: const TextStyle(fontSize: 14),
//                               ),
//                               Text(
//                                 item.description,
//                                 style: TextStyle(
//                                   fontSize: 13,
//                                   color: Colors.grey[700],
//                                   fontStyle: FontStyle.italic,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           subtitle: Text(
//                             '${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                               color: item.quantity <= 0
//                                   ? Colors.red
//                                   : item.quantity <= 3
//                                   ? Colors.orange
//                                   : Colors.green,
//                             ),
//                           ),
//                           trailing: item.imageUrl != null
//                               ? SizedBox(
//                                   width: 48,
//                                   height: 48,
//                                   child: ClipRRect(
//                                     borderRadius: BorderRadius.circular(4),
//                                     child: Image.network(
//                                       item.imageUrl!,
//                                       fit: BoxFit.cover,
//                                       loadingBuilder: (ctx, child, progress) {
//                                         if (progress == null) return child;
//                                         return Center(
//                                           child: SizedBox(
//                                             width: 24,
//                                             height: 24,
//                                             child: CircularProgressIndicator(
//                                               value:
//                                                   progress.expectedTotalBytes !=
//                                                       null
//                                                   ? progress.cumulativeBytesLoaded /
//                                                         progress
//                                                             .expectedTotalBytes!
//                                                   : null,
//                                               strokeWidth: 2,
//                                             ),
//                                           ),
//                                         );
//                                       },
//                                       errorBuilder: (_, __, ___) {
//                                         return Container(
//                                           color: Colors.grey[200],
//                                           child: const Icon(
//                                             Icons.broken_image,
//                                             size: 24,
//                                             color: Colors.grey,
//                                           ),
//                                         );
//                                       },
//                                     ),
//                                   ),
//                                 )
//                               : null,
//                           onTap: () => Navigator.of(context).push(
//                             MaterialPageRoute(
//                               builder: (_) => ItemDetailScreen(
//                                 itemId: item.id,
//                                 isAdmin: isAdmin,
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//       // floatingActionButton: isAdmin
//       //     ? FloatingActionButton(
//       //         onPressed: () => Navigator.of(
//       //           context,
//       //         ).push(MaterialPageRoute(builder: (_) => const AddItemScreen())),
//       //         tooltip: 'Dodaj stock',
//       //         child: const Icon(Icons.add),
//       //       )
//       //     : null,
//       // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
//       // bottomNavigationBar: SafeArea(
//       //   child: BottomAppBar(
//       //     shape: const CircularNotchedRectangle(),
//       //     notchMargin: 6,
//       //     child: Padding(
//       //       padding: const EdgeInsets.symmetric(horizontal: 32),
//       //       child: Row(
//       //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       //         children: [
//       //           IconButton(
//       //             tooltip: 'Klienci',
//       //             icon: const Icon(Icons.group),
//       //             onPressed: () => Navigator.of(context).push(
//       //               MaterialPageRoute(
//       //                 builder: (_) => CustomerListScreen(isAdmin: isAdmin),
//       //               ),
//       //             ),
//       //           ),
//       //           IconButton(
//       //             tooltip: 'Skanuj',
//       //             icon: const Icon(Icons.qr_code_scanner),
//       //             onPressed: () => Navigator.of(
//       //               context,
//       //             ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
//       //           ),
//       //         ],
//       //       ),
//       //     ),
//       //   ),
//       // ),
//     );
//   }
// }
