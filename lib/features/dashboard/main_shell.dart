import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation shell that wraps the main tab screens.
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.sensors_outlined, activeIcon: Icons.sensors_rounded, label: 'Monitoring'),
    (icon: Icons.satellite_alt_outlined, activeIcon: Icons.satellite_alt_rounded, label: 'Crop Health'),
    (icon: Icons.psychology_outlined, activeIcon: Icons.psychology_rounded, label: 'Disease AI'),
    (icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance_rounded, label: 'Schemes'),
  ];

  static const _paths = ['/home', '/monitoring', '/crop-health', '/disease', '/schemes'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _paths.length; i++) {
      if (location.startsWith(_paths[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          context.go(_paths[index]);
        },
        destinations: _tabs
            .map((tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.activeIcon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}
