import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_drawer.dart';

/// - Mobile: BackButton
/// - Web: Drawer always visible on left
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
  final bool showPersistentDrawerOnWeb;

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
    this.showPersistentDrawerOnWeb = true,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final usePersistentDrawer = kIsWeb && widget.showPersistentDrawerOnWeb;

    // WEB fixed drawer
    if (usePersistentDrawer) {
      return Scaffold(
        body: Row(
          children: [
            const SizedBox(width: 240, child: AppDrawer()),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(
                backgroundColor: widget.backgroundColor,
                appBar: AppBar(
                  leading: null,
                  title: widget.titleWidget ?? Text(widget.title),
                  centerTitle: widget.centreTitle,
                  automaticallyImplyLeading: false,
                  actions: widget.actions,
                  bottom: widget.bottom,
                ),
                body: widget.body,
                floatingActionButton: widget.floatingActionButton,
                floatingActionButtonLocation:
                    widget.floatingActionButtonLocation,
                bottomNavigationBar: widget.bottomNavigationBar,
              ),
            ),
          ],
        ),
      );
    }

    final bool isMobile = !kIsWeb;
    final leading = isMobile && widget.showBackOnMobile
        ? const BackButton()
        : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor,
      drawer: isMobile ? const AppDrawer() : null, // no drawer on web HOME
      drawerEdgeDragWidth: isMobile
          ? MediaQuery.of(context).size.width + 0.2
          : 0,
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
          if (isMobile && _scaffoldKey.currentState?.isDrawerOpen == true) {
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
