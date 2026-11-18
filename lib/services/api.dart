// Every Firestore read and write the app makes.
// Ported from the web app's src/lib/api.js, chat.js and public-chat.js.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../logic/chat_contract.dart';
import '../logic/errors.dart';
import '../models.dart';
import 'online.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;
CollectionReference<Json> _col(String name) => _db.collection(name);
Object get _now => FieldValue.serverTimestamp();

void _requireOnline() {
  if (!Online.instance.isOnline) throw const AppException('app/offline');
}

List<T> _oldestFirst<T>(List<T> rows, Timestamp? Function(T) created) {
  final indexed = rows.asMap().entries.toList()
    ..sort((a, b) {
      final c = createdMillis(created(a.value)).compareTo(createdMillis(created(b.value)));
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

// ---------------------------------------------------------------------------
// Live lists
// ---------------------------------------------------------------------------

Stream<List<Member>> watchMembers() =>
    _col('members').snapshots().map((s) => s.docs.map(Member.fromDoc).toList());

/// Newest first, like the web app.
Stream<List<Issue>> watchIssues() => _col('issues')
    .snapshots()
    .map((s) => _oldestFirst(s.docs.map(Issue.fromDoc).toList(), (i) => i.createdAt).reversed.toList());

Stream<List<Task>> watchTasks() =>
    _col('tasks').snapshots().map((s) => _oldestFirst(s.docs.map(Task.fromDoc).toList(), (t) => t.createdAt));

/// Comments load per task, so comments left behind by a deleted task never show up anywhere.
Stream<List<Comment>> watchTaskComments(String taskId) => _col('comments')
    .where('taskId', isEqualTo: taskId)
    .snapshots()
    .map((s) => _oldestFirst(s.docs.map(Comment.fromDoc).toList(), (c) => c.createdAt));

Stream<List<Comment>> watchIssueComments(String issueId) => _col('issueComments')
    .where('issueId', isEqualTo: issueId)
    .snapshots()
    .map((s) => _oldestFirst(s.docs.map(Comment.fromDoc).toList(), (c) => c.createdAt));

// ---------------------------------------------------------------------------
// Members
// ---------------------------------------------------------------------------

Future<void> saveNewMember(String uid, {required String name, required String email, required String phone}) =>
    _col('members').doc(uid).set({'name': name, 'email': email, 'phone': phone, 'createdAt': _now});

Future<void> updateMember(String uid, Json patch) async {
  _requireOnline();
  await _col('members').doc(uid).update(patch);
}

// ---------------------------------------------------------------------------
// Issues and tasks
// ---------------------------------------------------------------------------

Future<String> createIssue(String uid,
    {required String title, required String description, required String status, String? dueDate}) async {
  _requireOnline();
  final ref = await _col('issues').add({
    'title': title,
    'description': description,
    'status': status,
    'dueDate': dueDate,
    'ownerId': uid,
    'createdAt': _now,
  });
  return ref.id;
}

Future<void> updateIssue(String id, Json patch) async {
  _requireOnline();
  await _col('issues').doc(id).update(patch);
}

Future<String> createTask(String uid,
    {required String issueId,
    required String title,
    required String description,
    required String status,
    String? assigneeId,
    String? dueDate}) async {
  _requireOnline();
  final ref = await _col('tasks').add({
    'issueId': issueId,
    'title': title,
    'description': description,
    'status': status,
    'assigneeId': assigneeId,
    'dueDate': dueDate,
    'createdBy': uid,
    'createdAt': _now,
  });
  return ref.id;
}

Future<void> updateTask(String id, Json patch) async {
  _requireOnline();
  await _col('tasks').doc(id).update(patch);
}

Future<void> takeTask(String id, String uid) async {
  _requireOnline();
  try {
    await _col('tasks').doc(id).update({'assigneeId': uid});
  } on FirebaseException catch (e) {
    // The rules only let this fail when someone else claimed it first.
    if (e.code == 'permission-denied') throw const AppException('app/already-taken');
    rethrow;
  }
}

Future<void> deleteTask(String id) async {
  _requireOnline();
  await _col('tasks').doc(id).delete();
}

/// Deletes an issue and every task on it in one go. Owners and admins may do this.
Future<void> deleteIssueWithTasks(String issueId, List<String> taskIds) async {
  _requireOnline();
  final batch = _db.batch();
  for (final id in taskIds) {
    batch.delete(_col('tasks').doc(id));
  }
  batch.delete(_col('issues').doc(issueId));
  await batch.commit();
}

// ---------------------------------------------------------------------------
// Comments (on tasks and on whole issues)
// ---------------------------------------------------------------------------

Future<void> addComment(String uid, String taskId, String text) async {
  _requireOnline();
  await _col('comments').add({'taskId': taskId, 'authorId': uid, 'text': text, 'createdAt': _now});
}

Future<void> updateComment(String id, String text) async {
  _requireOnline();
  await _col('comments').doc(id).update({'text': text});
}

Future<void> deleteComment(String id) async {
  _requireOnline();
  await _col('comments').doc(id).delete();
}

Future<void> addIssueComment(String uid, String issueId, String text) async {
  _requireOnline();
  await _col('issueComments').add({'issueId': issueId, 'authorId': uid, 'text': text, 'createdAt': _now});
}

Future<void> updateIssueComment(String id, String text) async {
  _requireOnline();
  await _col('issueComments').doc(id).update({'text': text});
}

Future<void> deleteIssueComment(String id) async {
  _requireOnline();
  await _col('issueComments').doc(id).delete();
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

/// Only admins can read these full lists.
Stream<List<String>> watchAdminIds() =>
    _col('admins').snapshots().map((s) => s.docs.map((d) => d.id).toList());

Stream<List<Ban>> watchBans() => _col('bans').snapshots().map((s) => s.docs.map(Ban.fromDoc).toList());

/// Records the ban, deletes their profile, and frees the tasks they held.
Future<void> kickMember(String adminUid, Member member, List<String> heldTaskIds) async {
  _requireOnline();
  final batch = _db.batch();
  batch.set(_col('bans').doc(member.id), {
    'name': member.name,
    'email': member.email,
    'phone': member.phone,
    'memberCreatedAt': member.createdAt,
    'bannedBy': adminUid,
    'createdAt': _now,
  });
  for (final id in heldTaskIds) {
    batch.update(_col('tasks').doc(id), {'assigneeId': null});
  }
  batch.delete(_col('members').doc(member.id));
  await batch.commit();
}

/// Lets a removed person back in and puts their profile back exactly as it was.
Future<void> unbanMember(Ban ban) async {
  _requireOnline();
  final batch = _db.batch();
  batch.delete(_col('bans').doc(ban.id));
  // Bans made before profiles were saved have no phone. Those people fill in their profile on next login.
  if (ban.phone.isNotEmpty) {
    batch.set(_col('members').doc(ban.id), {
      'name': ban.name,
      'email': ban.email,
      'phone': ban.phone,
      'createdAt': ban.memberCreatedAt,
    });
  }
  await batch.commit();
}

// ---------------------------------------------------------------------------
// Private conversations
// ---------------------------------------------------------------------------

Stream<List<Conversation>> watchConversations(String uid) => _col('conversations')
    .where('participantIds', arrayContains: uid)
    .snapshots()
    .map((s) => s.docs.map(Conversation.fromDoc).toList()
      ..sort((a, b) => (b.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(a.updatedAt?.millisecondsSinceEpoch ?? 0)));

Stream<Conversation?> watchConversation(String id) =>
    _col('conversations').doc(id).snapshots().map((s) => s.exists ? Conversation.fromDoc(s) : null);

Stream<List<ChatMessage>> watchConversationMessages(String id) => _col('conversations')
    .doc(id)
    .collection('messages')
    .orderBy('createdAt')
    .snapshots()
    .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

Future<String> openConversation(String uid, String otherUid) async {
  _requireOnline();
  final id = conversationIdFor(uid, otherUid);
  final participantIds = [uid, otherUid]..sort();
  final ref = _col('conversations').doc(id);
  await _db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (snap.exists) {
      final current = (snap.data()?['participantIds'] as List?)?.cast<String>() ?? const [];
      if (current.join('\u0000') != participantIds.join('\u0000')) {
        throw const AppException('app/invalid-conversation');
      }
      return;
    }
    tx.set(ref, {
      'participantIds': participantIds,
      'createdAt': _now,
      'updatedAt': _now,
      'lastMessage': '',
      'lastMessageId': null,
      'lastSenderId': null,
    });
  });
  return id;
}

Future<void> sendChatMessage(String conversationId, String senderId, String value) async {
  _requireOnline();
  final text = value.trim();
  if (text.isEmpty || text.length > maxChatMessageLength) throw const AppException('app/invalid-chat-message');
  final convRef = _col('conversations').doc(conversationId);
  final msgRef = convRef.collection('messages').doc();
  await _db.runTransaction((tx) async {
    final snap = await tx.get(convRef);
    final ids = (snap.data()?['participantIds'] as List?) ?? const [];
    if (!snap.exists || !ids.contains(senderId)) throw const AppException('app/chat-not-allowed');
    tx.set(msgRef, {'senderId': senderId, 'text': text, 'createdAt': _now});
    tx.update(convRef, {
      'updatedAt': _now,
      'lastMessage': text,
      'lastMessageId': msgRef.id,
      'lastSenderId': senderId,
    });
  });
}

// ---------------------------------------------------------------------------
// Public chat rooms. The General room is built in and has no document.
// ---------------------------------------------------------------------------

const generalRoomId = 'general';
const generalRoom = Room(id: generalRoomId, name: 'General', description: 'Anything about the community.', builtIn: true);
const maxRoomNameLength = 60;
const maxRoomDescriptionLength = 280;
const maxRoomMessageLength = 2000;

/// Member-made rooms, oldest first. The General room is not included.
Stream<List<Room>> watchRooms() =>
    _col('chatRooms').snapshots().map((s) => _oldestFirst(s.docs.map(Room.fromDoc).toList(), (r) => r.createdAt));

/// The room, or null when it doesn't exist (anymore).
Stream<Room?> watchRoom(String roomId) {
  if (roomId == generalRoomId) return Stream.value(generalRoom);
  return _col('chatRooms').doc(roomId).snapshots().map((s) => s.exists ? Room.fromDoc(s) : null);
}

Stream<List<ChatMessage>> watchRoomMessages(String roomId) => _col('chatRooms')
    .doc(roomId)
    .collection('messages')
    .orderBy('createdAt')
    .snapshots()
    .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

Future<String> createRoom(String uid, {required String name, required String description}) async {
  _requireOnline();
  final ref = await _col('chatRooms').add({
    'name': name.trim(),
    'description': description.trim(),
    'createdBy': uid,
    'createdAt': _now,
  });
  return ref.id;
}

Future<void> deleteRoom(String roomId) async {
  _requireOnline();
  await _col('chatRooms').doc(roomId).delete();
}

Future<void> sendRoomMessage(String roomId, String senderId, String value) async {
  _requireOnline();
  final text = value.trim();
  if (text.isEmpty || text.length > maxRoomMessageLength) throw const AppException('app/invalid-chat-message');
  await _col('chatRooms').doc(roomId).collection('messages').add({'senderId': senderId, 'text': text, 'createdAt': _now});
}

Future<void> deleteRoomMessage(String roomId, String messageId) async {
  _requireOnline();
  await _col('chatRooms').doc(roomId).collection('messages').doc(messageId).delete();
}
