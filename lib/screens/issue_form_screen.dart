// New and edit issue. Ported from src/pages/IssueForm.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/forms.dart';
import '../models.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../widgets/ui.dart';

class IssueFormScreen extends StatefulWidget {
  const IssueFormScreen({super.key, this.issueId});
  final String? issueId;
  @override
  State<IssueFormScreen> createState() => _IssueFormScreenState();
}

class _IssueFormScreenState extends State<IssueFormScreen> with ActionState {
  final formKey = GlobalKey<FormState>();
  late final Issue? issue = context.read<DataService>().issueById(widget.issueId ?? '');
  late final title = TextEditingController(text: issue?.title ?? '');
  late final description = TextEditingController(text: issue?.description ?? '');
  late String status = issue?.status ?? 'open';
  late String dueDate = issue?.dueDate ?? '';
  // What the form opened with, kept so closing can tell whether anything was changed.
  late final Map<String, Object?> initial = current;

  bool get isEdit => widget.issueId != null;
  Map<String, Object?> get current =>
      {'title': title.text, 'description': description.text, 'status': status, 'dueDate': dueDate};

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    final uid = context.read<AuthService>().uid;
    run(() async {
      final due = dueDate.isEmpty ? null : dueDate;
      if (isEdit) {
        await api.updateIssue(widget.issueId!, {
          'title': title.text.trim(),
          'description': description.text.trim(),
          'status': status,
          'dueDate': due,
        });
        if (mounted) context.pop();
      } else {
        final id = await api.createIssue(uid,
            title: title.text.trim(), description: description.text.trim(), status: status, dueDate: due);
        if (mounted) context.pushReplacement('/issue/$id');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final data = context.watch<DataService>();
    if (isEdit && issue == null) {
      return Scaffold(appBar: AppBar(title: const Text('Edit issue')), body: const FormHead(title: 'This issue is gone.'));
    }
    final isOwner = !isEdit || issue!.ownerId == auth.uid;
    final ownerId = issue?.ownerId ?? auth.uid;
    final ownerName = isOwner ? auth.member!.name : data.nameOf(ownerId);
    final dirty = hasUnsavedChanges(initial, current);

    return PopScope(
      canPop: !dirty || busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscard(context) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(isEdit ? 'Edit issue' : 'New issue')),
        body: Form(
          key: formKey,
          onChanged: () => setState(() {}),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            FormHead(
              title: isEdit ? 'Edit issue.' : 'New issue.',
              subtitle: !isEdit
                  ? 'Start something the group can pitch in on.'
                  : isOwner
                      ? "You started this one, so it's yours to change."
                      : '${firstName(ownerName)} started this one. Anyone can edit it.',
            ),
            ...spaced([
              LabeledField(label: 'Title', controller: title, maxLength: 120, required: true, hint: 'e.g. Spring Coat Drive'),
              LabeledField(
                  label: 'Description', controller: description, maxLength: 2000, maxLines: 6, hint: "What's this about? Where?"),
              DueDateField(value: dueDate, onChanged: (v) => setState(() => dueDate = v)),
              Segmented(label: 'Status', options: issueStatus, value: status, onChanged: (v) => setState(() => status = v)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Avatar(id: ownerId, name: ownerName, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'Owner: ${isOwner ? '$ownerName (you)' : ownerName}. ',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: 'Everyone can read and edit this issue and add tasks to it. Only the owner can delete it.'),
                  ])),
                ),
              ]),
              if (error.isNotEmpty) ErrorNote(error),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Saving…' : isEdit ? 'Save changes' : 'Create issue'),
              ),
            ], 18),
          ]),
        ),
      ),
    );
  }
}
