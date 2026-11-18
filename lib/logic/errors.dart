// Friendly error messages. Ported from src/lib/errors.js.
import 'package:firebase_auth/firebase_auth.dart';

/// An error the app raises itself, with a code from [_messages].
class AppException implements Exception {
  const AppException(this.code);
  final String code;
  @override
  String toString() => 'AppException($code)';
}

const _sameCredentials = "That email and password don't match. Check them and try again.";
const _unreachable = "Can't reach the server. Check your connection and try again.";

const _messages = {
  'email-already-in-use': 'That email already has an account. Each email can only be used once.',
  'invalid-email': "That doesn't look like an email address.",
  'weak-password': 'That password is too weak. Use at least 8 characters.',
  'wrong-password': _sameCredentials,
  'invalid-credential': _sameCredentials,
  'user-not-found': _sameCredentials,
  'too-many-requests': 'Too many tries. Wait a few minutes, then try again.',
  'network-request-failed': _unreachable,
  'user-token-expired': 'You need to log in again.',
  'permission-denied': "You don't have permission to do that.",
  'unavailable': _unreachable,
  'app/offline': "You're offline. This works again once you're back online.",
  'app/already-taken': 'Someone else just took this task.',
  'app/invalid-conversation': 'This conversation could not be opened.',
  'app/invalid-chat-message': 'Enter a message up to 2000 characters.',
  'app/chat-not-allowed': "You can't send messages in this conversation.",
};

String? errorCode(Object? error) {
  if (error is AppException) return error.code;
  if (error is FirebaseAuthException) return error.code;
  if (error is FirebaseException) return error.code;
  return null;
}

String friendlyError(Object? error) =>
    _messages[errorCode(error)] ?? 'Something went wrong. Please try again.';
