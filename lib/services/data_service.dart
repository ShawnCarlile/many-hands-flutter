// Live members, issues and tasks for the whole community.
// A community is small, so live listeners on the three shared collections keep every screen simple and current.
// Ported from the web app's src/lib/data.jsx.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'api.dart' as api;

class DataService extends ChangeNotifier {
  List<Member>? _members;
  List<Issue>? _issues;
  List<Task>? _tasks;
  Map<String, Member> _memberById = const {};
  final _subs = <StreamSubscription<Object?>>[];
  bool _running = false;

  /// Starts the listeners once the signed-in member is allowed in, and stops them otherwise.
  void setActive(bool active) {
    if (active == _running) return;
    _running = active;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _members = _issues = _tasks = null;
    _memberById = const {};
    if (active) {
      void onError(Object e) => debugPrint('data listener: $e');
      _subs.add(api.watchMembers().listen((m) {
        _members = m..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _memberById = {for (final x in m) x.id: x};
        notifyListeners();
      }, onError: onError));
      _subs.add(api.watchIssues().listen((i) {
        _issues = i;
        notifyListeners();
      }, onError: onError));
      _subs.add(api.watchTasks().listen((t) {
        _tasks = t;
        notifyListeners();
      }, onError: onError));
    }
    notifyListeners();
  }

  bool get loading => _members == null || _issues == null || _tasks == null;
  List<Member> get members => _members ?? const [];
  List<Issue> get issues => _issues ?? const [];
  List<Task> get tasks => _tasks ?? const [];

  Member? memberById(String? id) => id == null ? null : _memberById[id];
  String nameOf(String? id) => memberById(id)?.name ?? 'A former member';

  Issue? issueById(String id) {
    for (final i in issues) {
      if (i.id == id) return i;
    }
    return null;
  }

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Task> tasksFor(String issueId) => tasks.where((t) => t.issueId == issueId).toList();

  /// Member Workload Indicator: tasks a member holds across all issues, not counting finished ones.
  int activeTaskCount(String id) => tasks.where((t) => t.assigneeId == id && t.status != 'done').length;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
