import 'package:flutter/material.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/main_tab_scope.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'activity_history_screen.dart';
import 'profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, this.initialIndex = 0})
      : assert(initialIndex >= 0 && initialIndex < 4);

  final int initialIndex;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _index = widget.initialIndex;
  late final Set<int> _visited = {_index};

  void _select(int index) {
    if (index == _index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    return MainTabScope(
      index: _index,
      routeIsCurrent: routeIsCurrent,
      select: _select,
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _index != 0) _select(0);
        },
        child: Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              for (var index = 0; index < 4; index++)
                TickerMode(
                  enabled: routeIsCurrent && index == _index,
                  child: _visited.contains(index)
                      ? switch (index) {
                          0 => const HomeScreen(),
                          1 => const LeaderboardScreen(),
                          2 => const ActivityHistoryScreen(),
                          _ => const ProfileScreen(),
                        }
                      : const SizedBox.shrink(),
                ),
            ],
          ),
          bottomNavigationBar: MainNavigationBar(
            currentIndex: _index,
            onTap: _select,
          ),
        ),
      ),
    );
  }
}
