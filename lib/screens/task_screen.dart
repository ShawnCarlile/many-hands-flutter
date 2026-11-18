// A task's details, status, and comments. Ported from src/pages/TaskPanel.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/comments.dart';
import '../widgets/ui.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key, required this.taskId});
  final String taskId;
  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> with ActionState {
  bool confirming = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<DataService>();
    if (data.loading) return const Scaffold(body: Loading());
    final task = data.taskById(widget.taskId);
    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task')),
        body: const PageHero(title: 'This task is gone.', lede: "It's no longer on the board."),
      );
    }
    final issue = data.issueById(task.issueId);
    final c = context.colors;
    final mine = task.assigneeId == auth.uid;
    final issueOwner = issue?.ownerId == auth.uid;
    final assigneeName = task.assigneeId != null ? data.nameOf(task.assigneeId) : null;

    void setStatus(String status) => run(() => api.updateTask(task.id, {'status': status}));
    void giveBack() => run(() => api.updateTask(task.id, {'assigneeId': null, 'status': 'todo'}));
    void reassign(String? id) => run(() => api.updateTask(task.id, id != null ? {'assigneeId': id} : {'assigneeId': null, 'status': 'todo'}));
    void remove() => run(() async {
          await api.deleteTask(task.id);
          if (context.mounted) context.pop();
        });

    final deleteRow = !confirming
        ? TextButton(
            style: TextButton.styleFrom(foregroundColor: c.danger),
            onPressed: () => setState(() => confirming = true),
            child: const Text('Delete'),
          )
        : ConfirmRow(
            question: 'Delete this task for everyone?',
            busy: busy,
            onConfirm: remove,
            onCancel: () => setState(() => confirming = false),
          );

    return Scaffold(
      appBar: AppBar(title: Text(task.title, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced([
            Wrap(spacing: 8, runSpacing: 8, children: [StatusBadge(task.status), DueBadge(task)]),
            Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
            if (task.assigneeId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: Avatar(id: task.assigneeId, name: assigneeName!, size: 28),
                  label: Text('Assigned to ${mine ? 'you' : assigneeName}'),
                  onPressed: () => context.push(mine ? '/me' : '/member/${task.assigneeId}'),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.openBg, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Muted("No one yet. Take it and it's yours."),
                  const SizedBox(height: 8),
                  TakeButton(taskId: task.id),
                ]),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.bgAlt, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FieldLabel('Description'),
                Text(task.description.isEmpty ? 'No description yet.' : task.description),
                const SizedBox(height: 10),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  const Muted('Part of ', small: true),
                  InkWell(
                    onTap: () => context.push('/issue/${task.issueId}'),
                    child: Text(issue?.title ?? 'this issue', style: TextStyle(color: c.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Muted(' · created by ${data.nameOf(task.createdBy)}', small: true),
                ]),
              ]),
            ),
            if (mine)
              _OwnerBox(children: [
                Segmented(label: 'Update status', options: taskStatus, value: task.status, onChanged: setStatus, enabled: !busy),
                Wrap(spacing: 4, children: [
                  if (!confirming) ...[
                    TextButton(onPressed: () => context.push('/task/${task.id}/edit'), child: const Text('Edit task ›')),
                    TextButton(onPressed: busy ? null : giveBack, child: const Text('Give it back')),
                  ],
                ]),
                deleteRow,
                ErrorNote(error),
              ]),
            if (issueOwner && !mine)
              _OwnerBox(children: [
                const FieldLabel('Assigned to'),
                DropdownButtonFormField<String?>(
                  initialValue: task.assigneeId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unassigned')),
                    // Member Workload Indicator
                    for (final m in data.members)
                      DropdownMenuItem(
                        value: m.id,
                        child: Text('${m.id == auth.uid ? '${m.name} (you)' : m.name} ${workloadLabel(data.activeTaskCount(m.id))}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: busy ? null : reassign,
                ),
                deleteRow,
                ErrorNote(error),
              ]),
            if (!issueOwner && !mine && task.assigneeId != null)
              LockNote('Only ${firstName(assigneeName!)} can edit, update or delete this task.'),
            if (!issueOwner && task.assigneeId == null) const LockNote('Whoever takes this task can edit or delete it.'),
          ], 14)),
        ),
        Band(alt: true, children: [
          CommentThread(
            title: 'Comments',
            placeholder: 'Add a comment',
            footer: 'Everyone can comment. Only the author can edit or delete their comment.',
            kind: CommentThreadKind(
              watch: () => api.watchTaskComments(task.id),
              add: (uid, text) => api.addComment(uid, task.id, text),
              update: api.updateComment,
              delete: api.deleteComment,
              adminCanDelete: false,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _OwnerBox extends StatelessWidget {
  const _OwnerBox({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.accent.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced(children, 8)),
      );
}
