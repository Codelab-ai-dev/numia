import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/n_bottom_nav.dart';

/// Set to true when user taps "Explorar sin cuenta"
bool skipAuth = false;

/// Shell con bottom nav
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _routes = ['/', '/budget', '/transactions', '/coach', '/goals', '/profile'];

  int _indexFromRoute(String location) {
    final idx = _routes.indexOf(location);
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: NBottomNav(
        currentIndex: _indexFromRoute(location),
        onTap: (i) => context.go(_routes[i]),
      ),
    );
  }
}
