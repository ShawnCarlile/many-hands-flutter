// Due dates are calendar days stored as 'YYYY-MM-DD', so they never shift with time zones.
// Ported from the web app's src/lib/dates.js.
import 'package:intl/intl.dart';

/// Anything with an optional due date and a status: tasks and issues.
abstract class Dated {
  String? get dueDate;
  String get status;
}

String _pad(int n) => n.toString().padLeft(2, '0');

String toISODate(DateTime date) => '${date.year}-${_pad(date.month)}-${_pad(date.day)}';

String todayISO([DateTime? now]) => toISODate(now ?? DateTime.now());

/// A local-midnight DateTime for a 'YYYY-MM-DD' string.
DateTime parseLocal(String iso) {
  final parts = iso.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

// A done task or a resolved issue is never overdue.
const _finished = {'done', 'resolved'};

bool isFinished(Dated item) => _finished.contains(item.status);

bool isOverdue(Dated item, [DateTime? now]) {
  final due = item.dueDate;
  return due != null && due.isNotEmpty && due.compareTo(todayISO(now)) < 0 && !isFinished(item);
}

String formatDue(String iso, [DateTime? now]) {
  final date = parseLocal(iso);
  final today = parseLocal(todayISO(now));
  final days = (date.difference(today).inHours / 24).round();
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days == -1) return 'Yesterday';
  final pattern = date.year != today.year ? 'EEE, MMM d, y' : 'EEE, MMM d';
  return DateFormat(pattern).format(date);
}

/// Dated items first, soonest first. Undated items keep their order (use with [stableSorted]).
int bySoonestDue(Dated a, Dated b) {
  final ad = a.dueDate, bd = b.dueDate;
  final hasA = ad != null && ad.isNotEmpty;
  final hasB = bd != null && bd.isNotEmpty;
  if (hasA && hasB) return ad.compareTo(bd);
  if (hasA) return -1;
  if (hasB) return 1;
  return 0;
}

/// Dart's List.sort isn't stable, so ties keep their original order here.
List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = items.toList().asMap().entries.toList();
  indexed.sort((a, b) {
    final c = compare(a.value, b.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return [for (final e in indexed) e.value];
}

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _monthKey = RegExp(r'^\d{4}-\d{2}$');
bool isISODate(String? value) => value != null && _isoDate.hasMatch(value);
bool isMonthKey(String? value) => value != null && _monthKey.hasMatch(value);

/// Month keys are 'YYYY-MM'. DateTime handles month and year rollover.
String shiftMonth(String key, int delta) {
  final parts = key.split('-').map(int.parse).toList();
  return toISODate(DateTime(parts[0], parts[1] + delta, 1)).substring(0, 7);
}

/// Every day shown on a month calendar: whole weeks, Sunday to Saturday.
List<String> monthDays(String key) {
  final parts = key.split('-').map(int.parse).toList();
  final y = parts[0], m = parts[1];
  final first = DateTime(y, m, 1);
  final last = DateTime(y, m + 1, 0);
  // DateTime.weekday is 1 (Mon) to 7 (Sun); % 7 makes Sunday 0, like JS getDay().
  final start = DateTime(y, m, 1 - first.weekday % 7);
  final end = DateTime(y, m, last.day + (6 - last.weekday % 7));
  final days = <String>[];
  for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
    days.add(toISODate(d));
  }
  return days;
}
