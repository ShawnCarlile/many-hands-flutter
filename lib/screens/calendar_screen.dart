// Every dated issue and task on a month grid. Ported from src/pages/Calendar.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../logic/dates.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

class _Entry {
  _Entry.issue(Issue i)
      : kind = 'issue',
        item = i,
        issue = i,
        path = '/issue/${i.id}';
  _Entry.task(Task t, Issue i)
      : kind = 'task',
        item = t,
        issue = i,
        path = '/task/${t.id}';
  final String kind, path;
  final Dated item;
  final Issue issue;
  String get title => item is Issue ? (item as Issue).title : (item as Task).title;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late String selected = todayISO();
  late String month = selected.substring(0, 7);

  void select(String day) => setState(() {
        selected = day;
        month = day.substring(0, 7);
      });

  // Moving to another month selects today if it's in view, otherwise the 1st.
  void showMonth(String key) {
    final today = todayISO();
    select(today.startsWith(key) ? today : '$key-01');
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final c = context.colors;
    final today = todayISO();

    // Every dated issue and task, grouped by day. Tasks of a deleted issue are skipped.
    final byDay = <String, List<_Entry>>{};
    var undated = 0;
    for (final issue in data.issues) {
      if (issue.dueDate != null) {
        byDay.putIfAbsent(issue.dueDate!, () => []).add(_Entry.issue(issue));
      } else {
        undated++;
      }
    }
    for (final task in data.tasks) {
      final issue = data.issueById(task.issueId);
      if (issue == null) continue;
      if (task.dueDate != null) {
        byDay.putIfAbsent(task.dueDate!, () => []).add(_Entry.task(task, issue));
      } else {
        undated++;
      }
    }

    Color dotColor(_Entry e) {
      if (isOverdue(e.item)) return c.riskFg;
      if (isFinished(e.item)) return c.ink2;
      return e.kind == 'issue' ? c.openFg : c.accent;
    }

    final days = monthDays(month);
    final monthTitle = DateFormat.yMMMM().format(parseLocal('$month-01'));
    final selectedDate = DateFormat.MMMMEEEEd().format(parseLocal(selected));
    final dayEntries = byDay[selected] ?? const <_Entry>[];
    // Jan 1 2023 was a Sunday, so these come out Sun to Sat.
    final weekdays = [for (var i = 0; i < 7; i++) DateFormat.E().format(DateTime(2023, 1, 1 + i))];

    return TabPage(title: 'Calendar', children: [
      const PageHero(
        eyebrow: communityName,
        title: 'Calendar.',
        lede: "Every issue and task with a due date. Select a day to see what's due.",
      ),
      Band(alt: true, children: [
        Row(children: [
          Expanded(child: Text(monthTitle, style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(tooltip: 'Previous month', icon: const Icon(Icons.chevron_left), onPressed: () => showMonth(shiftMonth(month, -1))),
          OutlinedButton(onPressed: () => select(today), child: const Text('Today')),
          IconButton(tooltip: 'Next month', icon: const Icon(Icons.chevron_right), onPressed: () => showMonth(shiftMonth(month, 1))),
        ]),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          children: [
            for (final w in weekdays)
              ExcludeSemantics(child: Center(child: Text(w, style: TextStyle(color: c.ink2, fontSize: 12, fontWeight: FontWeight.w600)))),
            for (final day in days)
              _DayCell(
                day: day,
                entries: byDay[day] ?? const [],
                inMonth: day.startsWith(month),
                isToday: day == today,
                isSelected: day == selected,
                dotColor: dotColor,
                onTap: () => select(day),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(selected == today ? 'Today, $selectedDate.' : '$selectedDate.', style: Theme.of(context).textTheme.titleMedium),
        if (dayEntries.isEmpty)
          EmptyNote('Nothing is due ${selected == today ? 'today' : 'this day'}.')
        else
          for (final e in dayEntries) _AgendaRow(entry: e),
        if (undated > 0)
          Muted(
            '$undated ${undated == 1 ? 'issue or task has' : 'issues and tasks have'} no due date, so '
            "${undated == 1 ? "it isn't" : "they aren't"} on the calendar.",
            small: true,
          ),
      ]),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entries,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.dotColor,
    required this.onTap,
  });
  final String day;
  final List<_Entry> entries;
  final bool inMonth, isToday, isSelected;
  final Color Function(_Entry) dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final date = parseLocal(day);
    final label = DateFormat.MMMMEEEEd().format(date) + (entries.isNotEmpty ? ', ${entries.length} due' : '');
    final ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? c.accent : null,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected ? Border.all(color: c.accent, width: 1.5) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? c.onAccent : inMonth ? ink : c.ink2.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final e in entries.take(3))
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: isSelected ? c.onAccent : dotColor(e), shape: BoxShape.circle),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.entry});
  final _Entry entry;
  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final data = context.watch<DataService>();
    final c = context.colors;
    String who(String id) => id == uid ? 'you' : data.nameOf(id);
    final item = entry.item;
    final detail = item is Issue
        ? 'Owner: ${who(item.ownerId)}'
        : 'Part of ${entry.issue.title} · ${(item as Task).assigneeId != null ? 'Assigned to ${who(item.assigneeId!)}' : 'No one yet'}';
    return TapCard(
      onTap: () => context.push(entry.path),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          entry.kind == 'issue'
              ? Tag('Issue', fg: c.openFg, bg: c.openBg)
              : Tag('Task', fg: Theme.of(context).colorScheme.onSurface, bg: c.todoBg),
          StatusBadge(item.status),
          if (isOverdue(item)) Tag('Overdue', fg: c.riskFg, bg: c.riskBg),
        ]),
        const SizedBox(height: 6),
        Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
        Muted(detail),
      ]),
    );
  }
}
