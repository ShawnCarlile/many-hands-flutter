// Issue and task cards. Ported from the web app's src/components/cards.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/health.dart';
import '../models.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import 'ui.dart';

String taskPath(Task task) => '/task/${task.id}';

class TakeButton extends StatefulWidget {
  const TakeButton({super.key, required this.taskId});
  final String taskId;
  @override
  State<TakeButton> createState() => _TakeButtonState();
}

class _TakeButtonState extends State<TakeButton> with ActionState {
  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      FilledButton(
        onPressed: busy ? null : () => run(() => api.takeTask(widget.taskId, uid)),
        child: Text(busy ? 'Taking…' : 'Take this task'),
      ),
      ErrorNote(error),
    ]);
  }
}

/// Unclaimed task card, as used on Home and at the top of the board.
class OpenTaskCard extends StatelessWidget {
  const OpenTaskCard({super.key, required this.task, this.issueTitle});
  final Task task;
  final String? issueTitle;
  @override
  Widget build(BuildContext context) {
    return TapCard(
      onTap: () => context.push(taskPath(task)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (issueTitle != null) Muted(issueTitle!, small: true),
        Text(task.title, style: Theme.of(context).textTheme.titleMedium),
        if (task.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(task.description, maxLines: 2)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusBadge(task.status),
          DueBadge(task),
          const Muted('No one yet', small: true),
        ]),
        const SizedBox(height: 10),
        TakeButton(taskId: task.id),
      ]),
    );
  }
}

/// Task somebody holds: who holds it, and who can change it.
class HeldTaskCard extends StatelessWidget {
  const HeldTaskCard({super.key, required this.task});
  final Task task;
  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final data = context.watch<DataService>();
    final c = context.colors;
    final mine = task.assigneeId == uid;
    final name = data.nameOf(task.assigneeId);
    return TapCard(
      onTap: () => context.push(taskPath(task)),
      border: mine ? c.accent : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(task.title, style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(width: 8),
          mine ? Tag('Yours', fg: c.accent, bg: c.accentSoft) : StatusBadge(task.status),
        ]),
        if (task.dueDate != null) Padding(padding: const EdgeInsets.only(top: 6), child: DueBadge(task)),
        const SizedBox(height: 6),
        if (mine) ...[
          Muted(taskStatus[task.status] ?? ''),
          Text('Open, edit or comment ›', style: TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
        ] else ...[
          Muted(name),
          const SizedBox(height: 4),
          LockNote('Only ${firstName(name)} can edit this.'),
        ],
      ]),
    );
  }
}

class IssueCard extends StatelessWidget {
  const IssueCard({super.key, required this.issue, this.tinted = false});
  final Issue issue;
  final bool tinted;
  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final data = context.watch<DataService>();
    final c = context.colors;
    final health = issueHealth(data.tasksFor(issue.id));
    final owner = issue.ownerId == uid ? 'you' : data.nameOf(issue.ownerId);
    final fraction = health.total == 0 ? 0.0 : health.assigned / health.total;
    final barColor = switch (health.label) {
      'Covered' => c.coveredFg,
      'Thin' => c.barThin,
      'At risk' => c.riskFg,
      _ => c.orphanFg,
    };
    return TapCard(
      color: tinted ? c.bgAlt : null,
      onTap: () => context.push('/issue/${issue.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(issue.title, style: Theme.of(context).textTheme.titleMedium),
              Muted('Owner: $owner · ${issueStatus[issue.status] ?? ''}'),
            ]),
          ),
          const SizedBox(width: 8),
          HealthBadge(health.label),
        ]),
        if (issue.dueDate != null) Padding(padding: const EdgeInsets.only(top: 8), child: DueBadge(issue)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: fraction, minHeight: 6, color: barColor, backgroundColor: c.todoBg),
        ),
        const SizedBox(height: 8),
        Muted(health.total > 0
            ? '${health.assigned} of ${health.total} ${health.total == 1 ? 'task has' : 'tasks have'} someone'
            : 'No tasks yet'),
      ]),
    );
  }
}

class MyTaskCard extends StatelessWidget {
  const MyTaskCard({super.key, required this.task});
  final Task task;
  @override
  Widget build(BuildContext context) {
    final issue = context.watch<DataService>().issueById(task.issueId);
    return TapCard(
      onTap: () => context.push(taskPath(task)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(task.title, style: Theme.of(context).textTheme.titleMedium)),
          StatusBadge(task.status),
        ]),
        Muted(issue?.title ?? 'Issue removed'),
        if (task.dueDate != null) Padding(padding: const EdgeInsets.only(top: 6), child: DueBadge(task)),
      ]),
    );
  }
}
