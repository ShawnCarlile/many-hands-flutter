// Ported from src/lib/chat-contract.js. The id format must match the web app and firestore.rules.
import 'errors.dart';

const maxChatMessageLength = 2000;

/// The two participant UIDs sorted, URI-encoded (with ~ encoded as %7E), then joined with ~.
String conversationIdFor(String uidA, String uidB) {
  if (uidA.trim().isEmpty || uidB.trim().isEmpty || uidA == uidB) {
    throw const AppException('app/invalid-conversation');
  }
  final ids = [uidA, uidB]..sort();
  return ids.map((uid) => Uri.encodeComponent(uid).replaceAll('~', '%7E')).join('~');
}
