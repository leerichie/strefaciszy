// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:strefa_ciszy/screens/filtered_report_screen.dart';
// import 'package:strefa_ciszy/widgets/app_scaffold.dart';

// class ReportsScreen extends StatefulWidget {
//   const ReportsScreen({super.key});

//   @override
//   State<ReportsScreen> createState() => _ReportsScreenState();
// }

// class _ReportsScreenState extends State<ReportsScreen> {
//   String _reportType = 'Miesięczny';
//   DateTimeRange? _customRange;
//   String? _selectedUser;
//   String? _selectedItem;
//   String _usageType = 'Wszystkie';

//   final List<String> reportOptions = [
//     'Tygodniowy',
//     'Miesięczny',
//     'Roczny',
//     'Zakres własny',
//   ];
//   final List<String> usageOptions = ['Wszystkie', 'Zużyte', 'Zwrócone'];
//   final title = 'Raporty';

//   @override
//   Widget build(BuildContext context) {
//     return AppScaffold(
//       showBackOnWeb: true,
//       title: title,
//       centreTitle: true,

//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Typ raportu:', style: TextStyle(fontWeight: FontWeight.bold)),
//             DropdownButton<String>(
//               value: _reportType,
//               items: reportOptions
//                   .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//                   .toList(),
//               onChanged: (value) => setState(() => _reportType = value!),
//             ),

//             if (_reportType == 'Zakres własny')
//               Row(
//                 children: [
//                   TextButton(
//                     onPressed: () async {
//                       final picked = await showDateRangePicker(
//                         context: context,
//                         firstDate: DateTime(2020),
//                         lastDate: DateTime.now(),
//                       );
//                       if (picked != null) setState(() => _customRange = picked);
//                     },
//                     child: Text(
//                       _customRange == null
//                           ? 'Wybierz zakres'
//                           : '${DateFormat('yyyy-MM-dd').format(_customRange!.start)} do ${DateFormat('yyyy-MM-dd').format(_customRange!.end)}',
//                     ),
//                   ),
//                 ],
//               ),

//             SizedBox(height: 16),
//             Text(
//               'Filtruj po użytkowniku:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             TextField(
//               decoration: InputDecoration(hintText: 'Nazwa użytkownika'),
//               onChanged: (val) => setState(() => _selectedUser = val.trim()),
//             ),

//             SizedBox(height: 16),
//             Text(
//               'Filtruj po materiale:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             TextField(
//               decoration: InputDecoration(hintText: 'Nazwa materiału'),
//               onChanged: (val) => setState(() => _selectedItem = val.trim()),
//             ),

//             SizedBox(height: 16),
//             Text('Typ zużycia:', style: TextStyle(fontWeight: FontWeight.bold)),
//             DropdownButton<String>(
//               value: _usageType,
//               items: usageOptions
//                   .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//                   .toList(),
//               onChanged: (value) => setState(() => _usageType = value!),
//             ),

//             SizedBox(height: 32),
//             Center(
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => FilteredReportScreen(
//                         reportType: _reportType,
//                         customRange: _customRange,
//                         userFilter: _selectedUser,
//                         itemFilter: _selectedItem,
//                         usageType: _usageType,
//                       ),
//                     ),
//                   );
//                 },
//                 child: Text('Generuj raport'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
