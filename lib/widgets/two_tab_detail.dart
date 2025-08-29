import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

class TwoTabDetailScaffold extends StatelessWidget {
  final Widget titleWidget;
  final List<Tab> tabs;
  final List<Widget> bodies;
  final List<FloatingActionButton?> fabs;

  const TwoTabDetailScaffold({
    super.key,
    required this.titleWidget,
    required this.tabs,
    required this.bodies,
    required this.fabs,
  });

  @override
  Widget build(BuildContext ctx) {
    return DefaultTabController(
      length: tabs.length,
      child: Builder(
        builder: (ctx2) {
          final tc = DefaultTabController.of(ctx2);
          return AnimatedBuilder(
            animation: tc,
            builder: (_, __) => AppScaffold(
              title: '',
              centreTitle: true,
              titleWidget: titleWidget,
              bottom: TabBar(tabs: tabs),
              body: TabBarView(children: bodies),
              floatingActionButton: fabs[tc.index],
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
            ),
          );
        },
      ),
    );
  }
}
