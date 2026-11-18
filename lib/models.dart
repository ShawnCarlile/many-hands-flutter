// Typed versions of the Firestore documents. Field names match the web app's data model
// (see README "Data model"), so both apps can share one Firebase project.
import 'package:cloud_firestore/cloud_firestore.dart';

import 'logic/dates.dart';

typedef Json = Map<String, dynamic>;

String _str(Object? v) => v is String ? v : '';
String? _optStr(Object? v) => v is String && v.isNotEmpty ? v : null;
Timestamp? _ts(Object? v) => v is Timestamp ? v : null;

/// Pending server timestamps are null on this device until the write lands; treat them as now.
int createdMillis(Timestamp? t) => t?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;

class Member {
  Member({required this.id, required this.name, required this.email, required this.phone, this.createdAt});
  factory Member.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? const {};
    return Member(id: d.id, name: _str(j['name']), email: _str(j['email']), phone: _str(j['phone']), createdAt: _ts(j['createdAt']));
  }
  final String id, name, email, phone;
  final Timestamp? createdAt;
}

class Issue implements Dated {
  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.ownerId,
    this.dueDate,
    this.createdAt,
  });
  factory Issue.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? const {};
    return Issue(
      id: d.id,
      title: _str(j['title']),
      description: _str(j['description']),
      status: _optStr(j['status']) ?? 'open',
      ownerId: _str(j['ownerId']),
      dueDate: _optStr(j['dueDate']),
      createdAt: _ts(j['createdAt']),
    );
  }
  final String id, title, description, ownerId;
  @override
  final String status; // open, in_progress, resolved
  @override
  final String? dueDate;
  final Timestamp? createdAt;
}

class Task implements Dated {
  Task({
    required this.id,
    required this.issueId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdBy,
    this.assigneeId,
    this.dueDate,
    this.createdAt,
  });
  factory Task.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? const {};
    return Task(
      id: d.id,
      issueId: _str(j['issueId']),
      title: _str(j['title']),
      description: _str(j['description']),
      status: _optStr(j['status']) ?? 'todo',
      createdBy: _str(j['createdBy']),
      assigneeId: _optStr(j['assigneeId']),
      dueDate: _optStr(j['dueDate']),
      createdAt: _ts(j['createdAt']),
    );
  }
  final String id, issueId, title, description, createdBy;
  @override
  final String status; // todo, doing, done
  final String? assigneeId;
  @override
  final String? dueDate;
  final Timestamp? createdAt;
}

/// A comment on a task (comments) or on an issue (issueComments).
class Comment {
  Comment({required this.id, required this.authorId, required this.text, this.createdAt});
  factory Comment.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? const {};
    return Comment(id: d.id, authorId: _str(j['authorId']), text: _str(j['text']), createdAt: _ts(j['createdAt']));
  }
  final String id, authorId, text;
  final Timestamp? createdAt;
}

class Conversation {
  Conversation({required this.id, required this.participantIds, required this.lastMessage, this.updatedAt});
  factory Conversation.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? const {};
    final ids = j['participantIds'];
    return Conversation(
      id: d.id,
      participantIds: ids is List ? ids.whereType<String>().toList() : const [],
      lastMessage: _str(j['lastMessage']),
      updatedAt: _ts(j['updatedAt']),
    );
  }
  final String id, lastMessage;
  final List<String> participantIds;
  final Timestamp? updatedAt;

  String? otherThan(String uid) {
    for (final id in participantIds) {
      if (id != uid) return id;
    }
    return null;
  }
}

class ChatMessage {
  ChatMessage({required this.id, required this.senderId, required this.text, this.createdAt});
  factory ChatMessage.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? const {};
    return ChatMessage(id: d.id, senderId: _str(j['senderId']), text: _str(j['text']), createdAt: _ts(j['createdAt']));
  }
  final String id, senderId, text;
  final Timestamp? createdAt;
}

class Room {
  const Room({required this.id, required this.name, required this.description, this.createdBy, this.createdAt, this.builtIn = false});
  factory Room.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? const {};
    return Room(
      id: d.id,
      name: _str(j['name']),
      description: _str(j['description']),
      createdBy: _optStr(j['createdBy']),
      createdAt: _ts(j['createdAt']),
    );
  }
  final String id, name, description;
  final String? createdBy;
  final Timestamp? createdAt;
  final bool builtIn;
}

class Ban {
  Ban({required this.id, required this.name, required this.email, required this.phone, this.memberCreatedAt, this.createdAt});
  factory Ban.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? const {};
    return Ban(
      id: d.id,
      name: _str(j['name']),
      email: _str(j['email']),
      phone: _str(j['phone']),
      memberCreatedAt: _ts(j['memberCreatedAt']),
      createdAt: _ts(j['createdAt']),
    );
  }
  final String id, name, email, phone;
  final Timestamp? memberCreatedAt, createdAt;
}

const taskStatus = {'todo': 'To do', 'doing': 'Doing', 'done': 'Done'};
const issueStatus = {'open': 'Open', 'in_progress': 'In progress', 'resolved': 'Resolved'};
