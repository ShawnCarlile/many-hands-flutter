// Admin tools: remove members, let them back in, edit or delete any issue.
// Ported from src/pages/Admin.jsx. Admins are added only in the Firebase console.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final admins = api.watchAdminIds();
  final bans = api.watchBans();

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final data = context.watch<DataService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const PageHero(
          eyebrow: 'Admin',
          title: 'Keep things tidy.',
          lede: "Remove members who shouldn't be here, and edit or delete any issue. Other admins can't be removed from here.",
        ),
        StreamBuilder<List<String>>(
          stream: admins,
          builder: (context, snap) {
            final adminIds = (snap.data ?? const []).toSet();
            return Band(alt: true, title: 'Members.', children: [
              for (final m in data.members)
                _MemberRow(
                  key: ValueKey(m.id),
                  member: m,
                  isSelf: m.id == uid,
                  isOtherAdmin: m.id != uid && adminIds.contains(m.id),
                  heldTaskIds: data.tasks.where((t) => t.assigneeId == m.id).map((t) => t.id).toList(),
                ),
            ]);
          },
        ),
        StreamBuilder<List<Ban>>(
          stream: bans,
          builder: (context, snap) {
            final list = snap.data;
            return Band(title: 'Removed.', children: [
              if (list == null && !snap.hasError)
                const Muted('Loading…')
              else if ((list ?? const []).isEmpty)
                const EmptyNote('Nobody has been removed.')
              else
                for (final b in list!) _BanRow(key: ValueKey(b.id), ban: b),
            ]);
          },
        ),
        Band(alt: true, title: 'All issues.', children: [
          if (data.issues.isEmpty) const EmptyNote('No issues yet.'),
          for (final i in data.issues)
            _IssueRow(
              key: ValueKey(i.id),
              issue: i,
              ownerName: i.ownerId == uid ? 'you' : data.nameOf(i.ownerId),
              taskIds: data.tasksFor(i.id).map((t) => t.id).toList(),
            ),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.main, required this.actions, this.below = const [], this.onTap});
  final Widget main;
  final List<Widget> actions, below;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => TapCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: main), ...actions]),
          ...below,
        ]),
      );
}

class _MemberRow extends StatefulWidget {
  const _MemberRow({super.key, required this.member, required this.isSelf, required this.isOtherAdmin, required this.heldTaskIds});
  final Member member;
  final bool isSelf, isOtherAdmin;
  final List<String> heldTaskIds;
  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> with ActionState {
  bool confirming = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = widget.member;
    final held = widget.heldTaskIds.length;
    return _Row(
      onTap: () => context.push(widget.isSelf ? '/me' : '/member/${m.id}'),
      main: Row(children: [
        Avatar(id: m.id, name: m.name, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Muted(m.email, small: true, maxLines: 1),
          ]),
        ),
      ]),
      actions: [
        if (widget.isSelf) Tag('You', fg: c.accent, bg: c.accentSoft),
        if (widget.isOtherAdmin) Tag('Admin', fg: c.orphanFg, bg: c.orphanBg),
        if (!widget.isSelf && !widget.isOtherAdmin && !confirming)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.danger),
            onPressed: () => setState(() => confirming = true),
            child: const Text('Kick'),
          ),
      ],
      below: [
        if (confirming)
          ConfirmRow(
            question: "Remove ${m.name}? They won't be able to use the app."
                "${held > 0 ? ' Their ${plural(held, 'task goes', 'tasks go')} back to Unclaimed.' : ''}",
            confirmLabel: 'Kick',
            cancelLabel: 'Cancel',
            busy: busy,
            onConfirm: () => run(() => api.kickMember(context.read<AuthService>().uid, m, widget.heldTaskIds)),
            onCancel: () => setState(() => confirming = false),
          ),
        ErrorNote(error),
      ],
    );
  }
}

class _BanRow extends StatefulWidget {
  const _BanRow({super.key, required this.ban});
  final Ban ban;
  @override
  State<_BanRow> createState() => _BanRowState();
}

class _BanRowState extends State<_BanRow> with ActionState {
  @override
  Widget build(BuildContext context) {
    final b = widget.ban;
    return _Row(
      main: Row(children: [
        Avatar(id: b.id, name: b.name, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.name.isEmpty ? 'Unknown member' : b.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Muted(b.email, small: true, maxLines: 1),
            Muted('Removed ${formatWhen(b.createdAt).toLowerCase()}', small: true),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: busy ? null : () => run(() => api.unbanMember(b)), child: Text(busy ? 'Letting back in…' : 'Let back in')),
      ],
      below: [ErrorNote(error)],
    );
  }
}

class _IssueRow extends StatefulWidget {
  const _IssueRow({super.key, required this.issue, required this.ownerName, required this.taskIds});
  final Issue issue;
  final String ownerName;
  final List<String> taskIds;
  @override
  State<_IssueRow> createState() => _IssueRowState();
}

class _IssueRowState extends State<_IssueRow> with ActionState {
  bool confirming = false;
  @override
  Widget build(BuildContext context) {
    final i = widget.issue;
    final count = widget.taskIds.length;
    return _Row(
      onTap: () => context.push('/issue/${i.id}'),
      main: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Muted('By ${widget.ownerName} · ${plural(count, 'task', 'tasks')}', small: true),
      ]),
      actions: [StatusBadge(i.status)],
      below: [
        if (!confirming)
          Row(children: [
            TextButton(onPressed: () => context.push('/issue/${i.id}/edit'), child: const Text('Edit')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: context.colors.danger),
              onPressed: () => setState(() => confirming = true),
              child: const Text('Delete'),
            ),
          ])
        else
          ConfirmRow(
            question: count > 0 ? 'Delete this issue and its ${plural(count, 'task', 'tasks')} for everyone?' : 'Delete this issue for everyone?',
            busy: busy,
            onConfirm: () => run(() => api.deleteIssueWithTasks(i.id, widget.taskIds)),
            onCancel: () => setState(() => confirming = false),
          ),
        ErrorNote(error),
      ],
    );
  }
}
