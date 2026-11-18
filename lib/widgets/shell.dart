// The bottom tab bar, the offline banner, and the shared tab app bar.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/online.dart';
import '../theme.dart';
import 'ui.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<DataService>().loading;
    return Scaffold(
      body: Column(children: [
        const OfflineBanner(),
        Expanded(child: loading ? const Loading() : shell),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Issues'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Chat'),
        ],
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final online = context.watch<Online>().isOnline;
    if (online) return const SizedBox.shrink();
    final c = context.colors;
    return Material(
      color: c.thinBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(Icons.cloud_off, size: 16, color: c.thinFg),
            const SizedBox(width: 8),
            Expanded(
              child: Text("You're offline. What you've already seen is saved on this device.",
                  style: TextStyle(color: c.thinFg, fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The signed-in member's avatar in the top corner. Opens the Me page.
class MeButton extends StatelessWidget {
  const MeButton({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final member = auth.member;
    if (member == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: 'Me',
        onPressed: () => context.push('/me'),
        icon: Avatar(id: member.id, name: member.name, size: 32),
      ),
    );
  }
}

/// A tab page: app bar with the Me button, and a scrolling body.
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.title, required this.children, this.fab});
  final String title;
  final List<Widget> children;
  final Widget? fab;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [MeButton()]),
      floatingActionButton: fab,
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: children),
    );
  }
}
