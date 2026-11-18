// Issue health, computed on the device from an issue's tasks. Text is always shown, never color alone.
// Ported from the web app's src/lib/health.js.
import '../models.dart';
import 'dates.dart';

class Health {
  const Health(this.label, this.total, this.assigned, this.unassigned);
  final String label; // Covered, Thin, At risk, Orphaned
  final int total;
  final int assigned;
  final int unassigned;
}

Health issueHealth(List<Task> tasks) {
  final total = tasks.length;
  final unassigned = tasks.where((t) => t.assigneeId == null).length;
  final assigned = total - unassigned;
  final String label;
  if (total == 0) {
    label = 'Orphaned';
  } else if (unassigned == 0) {
    label = 'Covered';
  } else if (unassigned > total / 2) {
    label = 'At risk';
  } else {
    label = 'Thin';
  }
  return Health(label, total, assigned, unassigned);
}

class TaskGroups {
  TaskGroups(this.unclaimed, this.todo, this.doing, this.done);
  final List<Task> unclaimed, todo, doing, done;
}

/// Unclaimed wins over status: a task nobody holds still needs someone.
TaskGroups groupTasks(List<Task> tasks) {
  final unclaimed = <Task>[], todo = <Task>[], doing = <Task>[], done = <Task>[];
  for (final task in tasks) {
    if (task.assigneeId == null) {
      unclaimed.add(task);
    } else if (task.status == 'todo') {
      todo.add(task);
    } else if (task.status == 'doing') {
      doing.add(task);
    } else if (task.status == 'done') {
      done.add(task);
    }
  }
  List<Task> s(List<Task> l) => stableSorted(l, bySoonestDue);
  return TaskGroups(s(unclaimed), s(todo), s(doing), s(done));
}

String healthSentence(Health h) {
  if (h.label == 'Orphaned') return 'No tasks yet. Add the first one.';
  if (h.label == 'Covered') return 'Every task has someone.';
  final left = '${h.unassigned} still ${h.unassigned == 1 ? 'needs' : 'need'} a person.';
  if (h.label == 'At risk') return 'Most tasks need someone. $left';
  return '${h.unassigned * 2 == h.total ? 'Half the' : 'Most'} tasks have someone. $left';
}
