// Comment threads, used for a task's comments and an issue's Discussion.
// Ported from TaskPanel.jsx's Comments and components/IssueComments.jsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'ui.dart';

/// Which kind of thread, and the calls that change it.
class CommentThreadKind {
  const CommentThreadKind({
    required this.watch,
    required this.add,
    required this.update,
    required this.delete,
    required this.adminCanDelete,
  });
  final Stream<List<Comment>> Function() watch;
  final Future<void> Function(String uid, String text) add;
  final Future<void> Function(String id, String text) update;
  final Future<void> Function(String id) delete;
  final bool adminCanDelete;
}

class CommentThread extends StatefulWidget {
  const CommentThread({
    super.key,
    required this.kind,
    required this.title,
    required this.placeholder,
    required this.footer,
    this.intro,
  });
  final CommentThreadKind kind;
  final String title, placeholder, footer;
  final String? intro;
  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> with ActionState {
  final draft = TextEditingController();
  late final Stream<List<Comment>> stream = widget.kind.watch();

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  void post() {
    final uid = context.read<AuthService>().uid;
    final text = draft.text.trim();
    if (text.isEmpty) return;
    run(() async {
      await widget.kind.add(uid, text);
      draft.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Comment>>(
      stream: stream,
      builder: (context, snap) {
        final comments = snap.data ?? const <Comment>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(width: 10),
            Muted(plural(comments.length, 'comment', 'comments')),
          ]),
          if (widget.intro != null) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(widget.intro!, small: true)),
          const SizedBox(height: 12),
          for (final c in comments) _CommentTile(key: ValueKey(c.id), comment: c, kind: widget.kind),
          Row(children: [
            Expanded(
              child: TextField(
                controller: draft,
                maxLength: 2000,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: widget.placeholder, counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: busy || draft.text.trim().isEmpty ? null : post, child: const Text('Post')),
          ]),
          ErrorNote(error),
          const SizedBox(height: 8),
          Muted(widget.footer, small: true),
        ]);
      },
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({super.key, required this.comment, required this.kind});
  final Comment comment;
  final CommentThreadKind kind;
  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> with ActionState {
  bool editing = false, confirming = false;
  late final text = TextEditingController(text: widget.comment.text);

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final data = context.watch<DataService>();
    final c = widget.comment;
    final mine = c.authorId == auth.uid;
    final canDelete = mine || (widget.kind.adminCanDelete && auth.isAdmin);
    final name = data.nameOf(c.authorId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(id: c.authorId, name: name, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$name${mine ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Muted(formatWhen(c.createdAt), small: true),
            ]),
          ),
          if (canDelete && !editing && !confirming) ...[
            if (mine)
              TextButton(
                onPressed: () => setState(() {
                  text.text = c.text;
                  editing = true;
                }),
                child: const Text('Edit'),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => setState(() => confirming = true),
              child: const Text('Delete'),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        if (editing) ...[
          TextField(controller: text, maxLength: 2000, minLines: 2, maxLines: 6, decoration: const InputDecoration(counterText: '')),
          Row(children: [
            FilledButton(
              onPressed: busy
                  ? null
                  : () {
                      final value = text.text.trim();
                      if (value.isEmpty) return;
                      run(() async {
                        await widget.kind.update(c.id, value);
                        if (mounted) setState(() => editing = false);
                      });
                    },
              child: const Text('Save'),
            ),
            TextButton(onPressed: () => setState(() => editing = false), child: const Text('Cancel')),
          ]),
        ] else
          Padding(padding: const EdgeInsets.only(left: 42), child: Text(c.text)),
        if (confirming)
          ConfirmRow(
            question: mine ? 'Delete this comment?' : "Delete $name's comment as an admin?",
            busy: busy,
            onConfirm: () => run(() => widget.kind.delete(c.id)),
            onCancel: () => setState(() => confirming = false),
          ),
        ErrorNote(error),
      ]),
    );
  }
}
