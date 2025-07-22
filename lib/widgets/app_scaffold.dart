import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_drawer.dart';

/// - Mobile: BackButton
/// - Web: Hamburger to open/close drawer
/// - Outside tap close on web
class AppScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final PreferredSizeWidget? bottom;
  final bool showBackOnMobile;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final bool? centreTitle;
  final Widget? titleWidget;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottom,
    this.showBackOnMobile = true,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.centreTitle,
    this.titleWidget,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _toggleDrawerWeb() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final leading = kIsWeb
        ? IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: _toggleDrawerWeb,
          )
        : (widget.showBackOnMobile ? const BackButton() : null);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor,
      drawer: const AppDrawer(),
      drawerEdgeDragWidth: kIsWeb ? 0 : MediaQuery.of(context).size.width + 0.2,
      appBar: AppBar(
        leading: leading,
        title: widget.titleWidget ?? Text(widget.title),
        centerTitle: widget.centreTitle,
        automaticallyImplyLeading: false,
        actions: widget.actions,
        bottom: widget.bottom,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (kIsWeb && _scaffoldKey.currentState?.isDrawerOpen == true) {
            Navigator.of(context).pop();
          }
        },
        child: widget.body,
      ),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}
