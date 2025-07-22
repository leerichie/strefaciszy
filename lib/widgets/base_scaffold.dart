// lib/widgets/base_scaffold.dart

import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_drawer.dart';

class BaseScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;

  final Widget body;

  final Widget? floatingActionButton;

  final int currentIndex;

  final ValueChanged<int>? onIndexChanged;

  const BaseScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    required this.currentIndex,
    this.onIndexChanged,
  });

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: appBar,
      body: Padding(
        padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.inventory_2,
                  color: currentIndex == 0 ? Colors.blue : Colors.grey,
                ),
                onPressed: () => onIndexChanged?.call(0),
                tooltip: 'Inwentaryzacja',
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: Icon(
                  Icons.person,
                  color: currentIndex == 1 ? Colors.blue : Colors.grey,
                ),
                onPressed: () => onIndexChanged?.call(1),
                tooltip: 'Klienci',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
