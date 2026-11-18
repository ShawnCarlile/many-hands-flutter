// Ported from src/pages/Home.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../logic/dates.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../widgets/cards.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

String _timeOfDay(DateTime d) => d.hour < 12 ? 'morning' : d.hour < 18 ? 'afternoon' : 'evening';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final openKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<DataService>();
    final now = DateTime.now();
    final part = _timeOfDay(now);
    final weekday = DateFormat.EEEE().format(now);

    final active = stableSorted(data.issues.where((i) => i.status != 'resolved'), bySoonestDue);
    String? issueTitle(String id) => data.issueById(id)?.title;
    // Skips tasks left behind by a deleted issue, since nobody can open those.
    final open = stableSorted(
        data.tasks.where((t) => t.status == 'todo' && t.assigneeId == null && issueTitle(t.issueId) != null), bySoonestDue);
    // What you're holding and haven't finished. Done tasks stay on the Me page.
    final mine = stableSorted(
        data.tasks.where((t) => t.assigneeId == auth.uid && t.status != 'done' && issueTitle(t.issueId) != null), bySoonestDue);
    final overdue = mine.where((t) => isOverdue(t)).length;

    return TabPage(title: communityName, children: [
      PageHero(
        eyebrow: '$weekday $part',
        title: 'Good $part, ${firstName(auth.member?.name ?? '')}.',
        lede: open.isNotEmpty
            ? "Glad you're here. A few tasks are still looking for someone."
            : "Glad you're here. Every open task has someone right now.",
        actions: [
          FilledButton(
            onPressed: () => Scrollable.ensureVisible(openKey.currentContext!, duration: const Duration(milliseconds: 400)),
            child: const Text('See open tasks'),
          ),
          TextButton(onPressed: () => context.go('/issues'), child: const Text('All issues ›')),
        ],
      ),
      if (mine.isNotEmpty)
        Band(
          title: 'Your tasks.',
          sub: '${mine.length} on your plate${overdue > 0 ? ', $overdue overdue' : ''}. Soonest due first.',
          children: [
            for (final t in mine) MyTaskCard(task: t),
            TextButton(
              onPressed: () => context.push('/me'),
              child: const Text("Everything you're on, including finished tasks ›"),
            ),
          ],
        ),
      Band(
        key: openKey,
        alt: true,
        header: const Align(alignment: Alignment.centerLeft, child: HealthBadge('Unclaimed')),
        title: 'Tasks that need someone.',
        sub: "Take one and it's assigned to you.",
        children: open.isEmpty
            ? [const EmptyNote('Nothing is waiting for someone right now.')]
            : [for (final t in open) OpenTaskCard(task: t, issueTitle: issueTitle(t.issueId))],
      ),
      Band(
        title: "What we're working on.",
        sub: plural(active.length, 'active issue', 'active issues'),
        children: active.isEmpty
            ? [
                EmptyNote('No active issues.',
                    action: TextButton(onPressed: () => context.push('/issue-new'), child: const Text('Start one'))),
              ]
            : [for (final i in active) IssueCard(issue: i, tinted: true)],
      ),
    ]);
  }
}
