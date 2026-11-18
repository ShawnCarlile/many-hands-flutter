// Ported from src/pages/IssueDetail.jsx.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/health.dart';
import '../models.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/comments.dart';
import '../widgets/ui.dart';

class IssueDetailScreen extends StatefulWidget {
  const IssueDetailScreen({super.key, required this.issueId});
  final String issueId;
  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> with ActionState {
  bool confirming = false;
  final keys = {for (final k in ['unclaimed', 'todo', 'doing', 'done']) k: GlobalKey()};

  void scrollTo(String group) {
    final ctx = keys[group]!.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<DataService>();
    if (data.loading) return const Scaffold(body: Loading());
    final issue = data.issueById(widget.issueId);
    if (issue == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const PageHero(title: 'This issue is gone.', lede: 'It may have been deleted by its owner.'),
      );
    }

    final tasks = data.tasksFor(issue.id);
    final health = issueHealth(tasks);
    final groups = groupTasks(tasks);
    final isOwner = issue.ownerId == auth.uid;
    final canDelete = isOwner || auth.isAdmin;
    final ownerName = data.nameOf(issue.ownerId);
    final started = groups.doing.length + groups.done.length;
    final title = issue.title.replaceAll(RegExp(r'[.!?]$'), '');

    void doDelete() => run(() async {
          // Owners and admins can delete every task on the issue, so they take them along with it.
          await api.deleteIssueWithTasks(issue.id, tasks.map((t) => t.id).toList());
          if (context.mounted) context.pop();
        });

    return Scaffold(
      appBar: AppBar(title: Text(issue.title, overflow: TextOverflow.ellipsis)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/issue/${issue.id}/task-new'),
        icon: const Icon(Icons.add_task),
        label: const Text('Add a task'),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$title.', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 34)),
            if (issue.description.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Muted(issue.description)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              StatusBadge(issue.status),
              DueBadge(issue),
            ]),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push(isOwner ? '/me' : '/member/${issue.ownerId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Avatar(id: issue.ownerId, name: ownerName, size: 28),
                  const SizedBox(width: 8),
                  Text('Owner: ${isOwner ? 'you' : ownerName}'),
                ]),
              ),
            ),
            if (auth.isAdmin && !isOwner)
              const Padding(padding: EdgeInsets.only(top: 6), child: Muted('You can delete this as an admin.', small: true)),
            if (groups.unclaimed.isNotEmpty)
              TextButton(onPressed: () => scrollTo('unclaimed'), child: const Text('See what still needs someone ›')),
            if (!confirming)
              Row(children: [
                TextButton(onPressed: () => context.push('/issue/${issue.id}/edit'), child: const Text('Edit')),
                if (canDelete)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: context.colors.danger),
                    onPressed: () => setState(() => confirming = true),
                    child: const Text('Delete'),
                  ),
              ])
            else
              ConfirmRow(
                question: tasks.isNotEmpty
                    ? 'Delete this issue and its ${plural(tasks.length, 'task', 'tasks')} for everyone?'
                    : 'Delete this issue for everyone?',
                busy: busy,
                onConfirm: doDelete,
                onCancel: () => setState(() => confirming = false),
              ),
            ErrorNote(error),
          ]),
        ),
        _HealthBand(
          health: health,
          started: started,
          todo: groups.todo.length,
          unclaimed: groups.unclaimed.length,
          onTile: scrollTo,
        ),
        Band(
          title: "Who's on what.",
          sub: "Take a task and it's yours. After that, only you can change it.",
          children: [
            _Group(key: keys['unclaimed'], title: 'Unclaimed', chip: 'Unclaimed', tasks: groups.unclaimed, open: true, empty: 'Nothing here. Every task has someone.'),
            _Group(key: keys['todo'], title: 'To do', chip: 'Thin', tasks: groups.todo, empty: 'Nobody is waiting to start.'),
            _Group(key: keys['doing'], title: 'Doing', chip: 'Covered', tasks: groups.doing, empty: 'Nothing underway yet.'),
            _Group(key: keys['done'], title: 'Done', chip: 'Covered', tasks: groups.done, empty: 'Nothing finished yet.'),
          ],
        ),
        Band(alt: true, children: [
          CommentThread(
            title: 'Discussion',
            intro: 'Talk about this issue as a whole. For a single task, open the task and comment there.',
            placeholder: 'Add to the discussion',
            footer: 'Everyone can comment. Only the author can edit their comment.',
            kind: CommentThreadKind(
              watch: () => api.watchIssueComments(issue.id),
              add: (uid, text) => api.addIssueComment(uid, issue.id, text),
              update: api.updateIssueComment,
              delete: api.deleteIssueComment,
              adminCanDelete: true,
            ),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: ExpansionTile(
            title: Text('How these labels work'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _LegendRow('Covered', 'Every task has someone. On the board, it marks tasks that are underway or done.'),
              _LegendRow('Thin', "Some tasks still need someone. On the board, it marks tasks someone holds but hasn't started."),
              _LegendRow('At risk', 'Most tasks still need someone.'),
              _LegendRow('Orphaned', 'The issue has no tasks yet.'),
            ],
          ),
        ),
      ]),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(this.label, this.text);
  final String label, text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Align(alignment: Alignment.centerLeft, child: HealthBadge(label))),
          Expanded(child: Text(text)),
        ]),
      );
}

class _Group extends StatelessWidget {
  const _Group({super.key, required this.title, required this.chip, required this.tasks, required this.empty, this.open = false});
  final String title, chip, empty;
  final List<Task> tasks;
  final bool open;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.colors.bgAlt, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 6),
          Muted('${tasks.length}'),
          const Spacer(),
          HealthBadge(chip),
        ]),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Muted(empty, small: true)
        else
          ...spaced([for (final t in tasks) open ? OpenTaskCard(task: t) : HeldTaskCard(task: t)], 10),
      ]),
    );
  }
}

class _HealthBand extends StatelessWidget {
  const _HealthBand({required this.health, required this.started, required this.todo, required this.unclaimed, required this.onTile});
  final Health health;
  final int started, todo, unclaimed;
  final ValueChanged<String> onTile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final caption = '${health.total == 1 ? 'task has' : 'tasks have'} someone';
    Widget tile(int n, String label, String group) => Expanded(
          child: Material(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTile(group),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Text('$n', style: TextStyle(color: c.inkInv, fontSize: 24, fontWeight: FontWeight.w700)),
                  Text(label, style: TextStyle(color: c.inkInv2, fontSize: 13)),
                ]),
              ),
            ),
          ),
        );
    return Container(
      color: c.bgDark,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(children: [
        Semantics(
          label: '${health.assigned} of ${health.total} $caption',
          child: SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _RingPainter(
                fraction: health.total == 0 ? 0 : health.assigned / health.total,
                track: c.ringTrack,
                fill: c.accentOnDark,
              ),
              child: Center(
                child: ExcludeSemantics(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${health.assigned}', style: TextStyle(color: c.inkInv, fontSize: 48, fontWeight: FontWeight.w700)),
                    SizedBox(
                      width: 120,
                      child: Text('of ${health.total} $caption',
                          textAlign: TextAlign.center, style: TextStyle(color: c.inkInv2, fontSize: 13)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        HealthBadge(health.label),
        const SizedBox(height: 10),
        Text(healthSentence(health),
            textAlign: TextAlign.center, style: TextStyle(color: c.inkInv, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Row(children: [
          tile(started, 'Covered', 'doing'),
          const SizedBox(width: 10),
          tile(todo, 'Thin', 'todo'),
          const SizedBox(width: 10),
          tile(unclaimed, 'Unclaimed', 'unclaimed'),
        ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track, required this.fill});
  final double fraction;
  final Color track, fill;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    canvas.drawArc(ring, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    if (fraction > 0) {
      canvas.drawArc(ring, -math.pi / 2, math.pi * 2 * fraction, false, Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.track != track || old.fill != fill;
}
