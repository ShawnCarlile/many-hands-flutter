// Dart ports of the web app's unit tests (tests/*.test.js), so both apps agree.
import 'package:flutter_test/flutter_test.dart';
import 'package:many_hands/logic/chat_contract.dart';
import 'package:many_hands/logic/dates.dart';
import 'package:many_hands/logic/errors.dart';
import 'package:many_hands/logic/filter.dart';
import 'package:many_hands/logic/forms.dart';
import 'package:many_hands/logic/health.dart';
import 'package:many_hands/logic/phone.dart';
import 'package:many_hands/models.dart';

Task task(String id, {String? assigneeId, String status = 'todo', String? dueDate}) =>
    Task(id: id, issueId: 'i', title: id, description: '', status: status, createdBy: 'u', assigneeId: assigneeId, dueDate: dueDate);

Issue issue(String id, String title, String description, String status) =>
    Issue(id: id, title: title, description: description, status: status, ownerId: 'u');

Member member(String id, String name, String email, String phone) => Member(id: id, name: name, email: email, phone: phone);

void main() {
  group('health', () {
    List<Task> tasks(int assigned, int unassigned) => [
          for (var i = 0; i < assigned; i++) task('a$i', assigneeId: 'a'),
          for (var i = 0; i < unassigned; i++) task('u$i'),
        ];
    test('Orphaned when an issue has no tasks', () => expect(issueHealth([]).label, 'Orphaned'));
    test('Covered when every task has an assignee', () => expect(issueHealth(tasks(3, 0)).label, 'Covered'));
    test('Thin when some are unassigned', () {
      expect(issueHealth(tasks(3, 1)).label, 'Thin');
      expect(issueHealth(tasks(2, 2)).label, 'Thin');
    });
    test('At risk when most are unassigned', () {
      expect(issueHealth(tasks(1, 2)).label, 'At risk');
      expect(issueHealth(tasks(0, 2)).label, 'At risk');
    });
    test('groups unclaimed first, then by status', () {
      final g = groupTasks([
        task('1', status: 'doing'),
        task('2', assigneeId: 'a'),
        task('3', assigneeId: 'a', status: 'doing'),
        task('4', assigneeId: 'a', status: 'done'),
      ]);
      expect([g.unclaimed.length, g.todo.length, g.doing.length, g.done.length], [1, 1, 1, 1]);
    });
    test('health sentence', () {
      expect(healthSentence(issueHealth(tasks(2, 2))), 'Half the tasks have someone. 2 still need a person.');
    });
  });

  group('dates', () {
    final now = DateTime(2026, 11, 11, 23, 30);
    test('todayISO uses the local calendar day', () {
      expect(todayISO(now), '2026-11-11');
      expect(todayISO(DateTime(2026, 1, 5)), '2026-01-05');
    });
    test('formatDue names nearby days', () {
      expect(formatDue('2026-11-11', now), 'Today');
      expect(formatDue('2026-11-12', now), 'Tomorrow');
      expect(formatDue('2026-11-10', now), 'Yesterday');
    });
    test('formatDue shows the local date, and the year only when it differs', () {
      expect(formatDue('2026-11-15', now), contains('15'));
      expect(formatDue('2026-11-15', now), isNot(contains('2026')));
      expect(formatDue('2027-01-03', now), contains('2027'));
    });
    test('isOverdue', () {
      expect(isOverdue(task('a', dueDate: '2026-11-10'), now), true);
      expect(isOverdue(task('a', dueDate: '2026-11-10', status: 'doing'), now), true);
      expect(isOverdue(task('a', dueDate: '2026-11-10', status: 'done'), now), false);
      expect(isOverdue(task('a', dueDate: '2026-11-11'), now), false);
      expect(isOverdue(task('a'), now), false);
      final i = Issue(id: 'i', title: '', description: '', status: 'resolved', ownerId: 'u', dueDate: '2026-11-10');
      expect(isOverdue(i, now), false);
    });
    test('bySoonestDue puts dated first, soonest first, and keeps undated order', () {
      final list = [task('a'), task('b', dueDate: '2026-12-01'), task('c'), task('d', dueDate: '2026-11-20'), task('e')];
      expect(stableSorted(list, bySoonestDue).map((t) => t.id), ['d', 'b', 'a', 'c', 'e']);
    });
    test('shiftMonth rolls over years', () {
      expect(shiftMonth('2026-11', 1), '2026-12');
      expect(shiftMonth('2026-12', 1), '2027-01');
      expect(shiftMonth('2026-01', -1), '2025-12');
    });
    test('monthDays covers whole Sunday-to-Saturday weeks', () {
      final days = monthDays('2026-11');
      expect(days.first, '2026-11-01');
      expect(days.last, '2026-12-05');
      expect(days.length % 7, 0);
      final feb = monthDays('2026-02');
      expect(feb.first, '2026-02-01');
      expect(feb.length, 28);
      final march = monthDays('2026-03');
      expect(march.first, '2026-03-01');
      expect(march.toSet().length, march.length);
      expect(march, containsAll(['2026-03-08', '2026-03-09']));
    });
  });

  group('filter', () {
    final issues = [
      issue('1', 'Fix the park benches', 'Two are broken', 'open'),
      issue('2', 'Food drive', 'Collect cans at the park', 'in_progress'),
      issue('3', 'Paint the fence', '', 'resolved'),
    ];
    List<String> ids(List<Issue> l) => l.map((i) => i.id).toList();
    test('issue views and search', () {
      expect(ids(filterIssues(issues)), ['1', '2']);
      expect(ids(filterIssues(issues, view: 'resolved')), ['3']);
      expect(ids(filterIssues(issues, view: 'all')), ['1', '2', '3']);
      expect(ids(filterIssues(issues, view: 'all', search: 'PARK')), ['1', '2']);
      expect(ids(filterIssues(issues, view: 'all', search: 'park cans')), ['2']);
      expect(ids(filterIssues(issues, view: 'all', search: '   ')), ['1', '2', '3']);
    });

    final members = [
      member('a', 'Ana Lopez', 'ana@example.com', '(989) 555-1234'),
      member('b', 'Ben Carter', 'bcarter@svsu.edu', '(517) 555-9876'),
      member('c', 'Chris Ana', 'chris@example.org', '(313) 222-0000'),
    ];
    List<String> mids(String q) => filterMembers(members, q).map((m) => m.id).toList();
    test('member search', () {
      expect(mids(''), ['a', 'b', 'c']);
      expect(mids('BEN'), ['b']);
      expect(mids('ana'), ['a', 'c']);
      expect(mids('svsu.edu'), ['b']);
      expect(mids('(989) 555-1234'), ['a']);
      expect(mids('9895551234'), ['a']);
      expect(mids('555-98'), ['b']);
      expect(mids('555'), ['a', 'b']);
      expect(mids('ana example.org'), ['c']);
      expect(mids('ana 989'), ['a']);
      expect(mids('zelda'), <String>[]);
      expect(mids('000-1111'), <String>[]);
      expect(mids('()'), <String>[]);
    });
  });

  group('phone', () {
    test('formats any common input the same way', () {
      for (final input in ['5551234567', '555-123-4567', '555.123.4567', '(555)123-4567', '+1 555 123 4567', '1-555-123-4567']) {
        expect(formatPhone(input), '(555) 123-4567', reason: input);
      }
    });
    test('partial input, length cap, and junk', () {
      expect(formatPhone(''), '');
      expect(formatPhone('5'), '(5');
      expect(formatPhone('5551'), '(555) 1');
      expect(formatPhone('5551234'), '(555) 123-4');
      expect(formatPhone('555123456789'), '(555) 123-4567');
      expect(formatPhone('abc'), '');
      expect(formatPhone('555-CALL-1234'), '(555) 123-4');
    });
    test('validity, display, and tel links', () {
      expect(isValidPhone('(555) 123-4567'), true);
      expect(isValidPhone('(555) 123-456'), false);
      expect(isValidPhone('5551234567'), false);
      expect(displayPhone('555.123.4567'), '(555) 123-4567');
      expect(displayPhone('555-0100'), '555-0100');
      expect(phoneUri('(555) 123-4567').toString(), 'tel:+15551234567');
    });
  });

  group('forms', () {
    final blank = {'title': '', 'description': '', 'status': 'open', 'dueDate': ''};
    final saved = {'title': 'Bring tables', 'status': 'doing', 'assigneeId': 'u1', 'dueDate': '2026-11-20'};
    test('detects real changes only', () {
      expect(hasUnsavedChanges(blank, {...blank}), false);
      expect(hasUnsavedChanges(blank, {...blank, 'title': 'Coat drive'}), true);
      expect(hasUnsavedChanges(blank, {...blank, 'status': 'resolved'}), true);
      expect(hasUnsavedChanges(saved, {...saved, 'dueDate': ''}), true);
      expect(hasUnsavedChanges(blank, {...blank, 'title': '   '}), false);
      expect(hasUnsavedChanges(saved, {...saved, 'title': 'Bring tables  '}), false);
      expect(hasUnsavedChanges({'dueDate': null}, {'dueDate': ''}), false);
    });
  });

  group('chat contract', () {
    test('ids are stable, encoded, and need two different members', () {
      expect(conversationIdFor('alice', 'bob'), conversationIdFor('bob', 'alice'));
      expect(conversationIdFor('a~b', 'c'), 'a%7Eb~c');
      expect(() => conversationIdFor('alice', 'alice'), throwsA(isA<AppException>()));
      expect(() => conversationIdFor('', 'bob'), throwsA(isA<AppException>()));
    });
  });
}
