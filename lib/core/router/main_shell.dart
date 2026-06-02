import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/tp_tab_bar.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const MainShell({super.key, required this.child, required this.state});

  static const _routes = ['/feed', '/map', '/messages', '/me'];

  int get _activeIndex {
    final loc = state.uri.path;
    final i = _routes.indexOf(loc);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: TpTabBar(
        activeIndex: _activeIndex,
        onTap: (i) => context.go(_routes[i]),
        onCreateTap: () => context.push('/event/new'),
      ),
    );
  }
}
