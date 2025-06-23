// lib/widgets/base_scaffold.dart
import 'package:flutter/material.dart';

class BaseScaffold extends StatelessWidget {
  /// The top bar
  final PreferredSizeWidget? appBar;

  /// Main content of the screen
  final Widget body;

  /// Optional FAB (e.g. Scan)
  final Widget? floatingActionButton;

  /// Which bottom‐nav item is active (0=inventory,1=clients,2=scan)
  final int currentIndex;

  /// Called when you tap the bottom‐nav items
  final ValueChanged<int>? onIndexChanged;

  const BaseScaffold({
    Key? key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    required this.currentIndex,
    this.onIndexChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext c) {
    return Scaffold(
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
