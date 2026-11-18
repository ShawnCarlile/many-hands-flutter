// New and edit task. Ported from src/pages/TaskForm.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/forms.dart';
import '../models.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class TaskFormScreen extends StatefulWidget {
  /// Pass [issueId] for a new task, or [taskId] to edit one.
  const TaskFormScreen({super.key, this.issueId, this.taskId});
  final String? issueId, taskId;
  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> with ActionState {
  final formKey = GlobalKey<FormState>();
  late final Task? task = context.read<DataService>().taskById(widget.taskId ?? '');
  late final title = TextEditingController(text: task?.title ?? '');
  late final description = TextEditingController(text: task?.description ?? '');
  late String status = task?.status ?? 'todo';
  late String assigneeId = task?.assigneeId ?? '';
  late String dueDate = task?.dueDate ?? '';
  // Tells the person a cleared date only applies once they save.
  bool dateCleared = false;
  late final Map<String, Object?> initial = current;

  bool get isEdit => widget.taskId != null;
  Map<String, Object?> get current => {
        'title': title.text,
        'description': description.text,
        'status': status,
        'assigneeId': assigneeId,
        'dueDate': dueDate,
      };

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    final uid = context.read<AuthService>().uid;
    final unassigned = assigneeId.isEmpty;
    final values = {
      'title': title.text.trim(),
      'description': description.text.trim(),
      'assigneeId': unassigned ? null : assigneeId,
      'dueDate': dueDate.isEmpty ? null : dueDate,
      // An unassigned task cannot be underway.
      'status': unassigned ? 'todo' : status,
    };
    run(() async {
      if (isEdit) {
        await api.updateTask(widget.taskId!, values);
        if (mounted) context.pop();
      } else {
        final id = await api.createTask(
          uid,
          issueId: widget.issueId!,
          title: values['title'] as String,
          description: values['description'] as String,
          status: values['status'] as String,
          assigneeId: values['assigneeId'],
          dueDate: values['dueDate'],
        );
        if (mounted) context.pushReplacement('/task/$id');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final data = context.watch<DataService>();
    final c = context.colors;

    // Only the assigned person can edit an existing task.
    if (isEdit && task?.assigneeId != auth.uid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit task')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const FormHead(title: 'Not yours to edit.'),
            LockNote(task?.assigneeId != null
                ? 'Only ${firstName(data.nameOf(task!.assigneeId))} can edit this task.'
                : 'Take this task first, then you can edit it.'),
          ]),
        ),
      );
    }

    // The signed-in member first in the list.
    final people = [...data.members]..sort((a, b) => (b.id == auth.uid ? 1 : 0) - (a.id == auth.uid ? 1 : 0));
    final unassigned = assigneeId.isEmpty;
    final holder = unassigned ? null : assigneeId == auth.uid ? 'you' : firstName(data.nameOf(assigneeId));
    final dirty = hasUnsavedChanges(initial, current);

    Widget assignRow({required String value, required Widget avatar, required String name, String? sub}) => RadioListTile<String>(
          value: value,
          contentPadding: EdgeInsets.zero,
          secondary: avatar,
          title: Text(name),
          subtitle: sub != null ? Text(sub) : null,
        );

    return PopScope(
      canPop: !dirty || busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscard(context) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(isEdit ? 'Edit task' : 'New task')),
        body: Form(
          key: formKey,
          onChanged: () => setState(() {}),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            FormHead(
              title: isEdit ? 'Edit task.' : 'New task.',
              subtitle: isEdit ? "It's assigned to you, so it's yours to change." : 'Add something the group needs done.',
            ),
            ...spaced([
              LabeledField(label: 'Title', controller: title, maxLength: 120, required: true, hint: 'e.g. Bring 2 folding tables'),
              LabeledField(
                  label: 'Description', controller: description, maxLength: 2000, maxLines: 6, hint: 'What does this involve? Where?'),
              DueDateField(
                value: dueDate,
                note: dateCleared ? 'Due date cleared. Save changes to apply.' : null,
                onChanged: (v) => setState(() {
                  dateCleared = v.isEmpty;
                  dueDate = v;
                }),
              ),
              if (!unassigned)
                Segmented(label: 'Status', options: taskStatus, value: status, onChanged: (v) => setState(() => status = v)),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const FieldLabel('Assign to'),
                RadioGroup<String>(
                  groupValue: assigneeId,
                  onChanged: (v) => setState(() => assigneeId = v ?? ''),
                  child: Column(children: [
                    assignRow(
                      value: '',
                      avatar: CircleAvatar(radius: 17, backgroundColor: c.todoBg, child: const Text('?')),
                      name: 'Leave unassigned',
                      sub: 'Anyone can take it',
                    ),
                    for (final p in people)
                      assignRow(
                        value: p.id,
                        avatar: Avatar(id: p.id, name: p.name, size: 34),
                        // Member Workload Indicator
                        name: '${p.name} ${workloadLabel(data.activeTaskCount(p.id))}',
                        sub: p.id == auth.uid ? 'You' : null,
                      ),
                  ]),
                ),
              ]),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.bgAlt, borderRadius: BorderRadius.circular(16)),
                child: unassigned
                    ? const Text(
                        'You can create a task for anyone. Whoever takes this one can then edit it, change its status, or delete it.')
                    : Text.rich(TextSpan(children: [
                        const TextSpan(text: "You can create a task for anyone. Once it's saved, only "),
                        TextSpan(text: holder, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(text: ' can edit it, change its status, or delete it.'),
                      ])),
              ),
              if (error.isNotEmpty) ErrorNote(error),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Saving…' : isEdit ? 'Save changes' : 'Create task'),
              ),
            ], 18),
          ]),
        ),
      ),
    );
  }
}
