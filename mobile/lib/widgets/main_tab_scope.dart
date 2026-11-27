import 'package:flutter/material.dart';

/// Navigation and visibility of the four top-level sections.
class MainTabScope extends InheritedWidget {
  const MainTabScope({
    super.key,
    required this.index,
    required this.routeIsCurrent,
    required this.select,
    required super.child,
  });

  final int index;
  final bool routeIsCurrent;
  final ValueChanged<int> select;

  bool isActive(int tab) => index == tab && routeIsCurrent;

  static MainTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainTabScope>();

  @override
  bool updateShouldNotify(MainTabScope oldWidget) =>
      index != oldWidget.index || routeIsCurrent != oldWidget.routeIsCurrent;
}

/// Lets a section retain its standalone entry point while the main shell owns
/// the Scaffold, keyboard resizing and bottom navigation when it is hosted.
class MainSection extends StatelessWidget {
  const MainSection({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.bottomNavigationBar,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    if (MainTabScope.maybeOf(context) == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      );
    }
    return ColoredBox(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          if (appBar != null)
            SizedBox(
              height: appBar!.preferredSize.height +
                  MediaQuery.paddingOf(context).top,
              child: appBar,
            ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: SafeArea(top: false, bottom: false, child: body),
            ),
          ),
        ],
      ),
    );
  }
}
