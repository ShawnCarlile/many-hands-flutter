// Sign-in state, the signed-in member's profile, and whether they're an admin or removed.
// Ported from the web app's src/lib/auth.jsx.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import 'api.dart' as api;

enum AuthStatus { loading, signedOut, removed, needsProfile, ready }

class AuthService extends ChangeNotifier {
  AuthService() {
    _authSub = _auth.authStateChanges().listen(_onUser);
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Json>>? _banSub, _adminSub, _memberSub;

  bool _userLoaded = false;
  User? _user;
  bool? _banned; // null = still loading
  bool _memberLoaded = false;
  Member? _member;
  bool _isAdmin = false;
  bool _signingUp = false;

  User? get user => _user;
  String get uid => _user!.uid;
  Member? get member => _member;
  bool get isAdmin => _isAdmin;

  AuthStatus get status {
    if (!_userLoaded) return AuthStatus.loading;
    if (_user == null) return AuthStatus.signedOut;
    if (_banned == null) return AuthStatus.loading;
    if (_banned!) return AuthStatus.removed;
    if (!_memberLoaded) return AuthStatus.loading;
    if (_member == null) return AuthStatus.needsProfile;
    return AuthStatus.ready;
  }

  void _onUser(User? user) {
    _banSub?.cancel();
    _adminSub?.cancel();
    _stopMember();
    _user = user;
    _userLoaded = true;
    _banned = null;
    _isAdmin = false;
    if (user != null) {
      // Admins live in admins/{uid}, set up in the Firebase console. Bans live in bans/{uid}.
      _banSub = _db.collection('bans').doc(user.uid).snapshots().listen(
        (snap) => _setBanned(snap.exists),
        onError: (Object e) {
          debugPrint('ban listener: $e');
          _setBanned(false);
        },
      );
      _adminSub = _db.collection('admins').doc(user.uid).snapshots().listen(
        (snap) {
          _isAdmin = snap.exists;
          notifyListeners();
        },
        // A removed person can't read this, and that's fine: they aren't an admin.
        onError: (Object _) {
          _isAdmin = false;
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  // Wait until we know the user isn't removed: the rules refuse a removed person's reads,
  // and a refused listener stops for good, so it has to start again after a ban is lifted.
  void _setBanned(bool banned) {
    final changed = _banned != banned;
    _banned = banned;
    if (changed) {
      _stopMember();
      if (!banned) _startMember();
    }
    notifyListeners();
  }

  void _stopMember() {
    _memberSub?.cancel();
    _memberSub = null;
    _memberLoaded = false;
    _member = null;
  }

  void _startMember() {
    final user = _user;
    if (user == null) return;
    _memberSub = _db.collection('members').doc(user.uid).snapshots().listen(
      (snap) {
        // A missing doc in the cache proves nothing, so wait for the server's answer.
        if (!snap.exists && (snap.metadata.isFromCache || _signingUp)) return;
        _member = snap.exists ? Member.fromDoc(snap) : null;
        _memberLoaded = true;
        notifyListeners();
        // After a verified email change, the Auth email is newer than the profile. Catch up here.
        final email = _auth.currentUser?.email;
        if (_member != null && email != null && _member!.email != email) {
          api.updateMember(user.uid, {'email': email}).catchError((_) {});
        }
      },
      onError: (Object e) => debugPrint('member listener: $e'),
    );
  }

  Future<void> logIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signUp({required String name, required String phone, required String email, required String password}) async {
    _signingUp = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await api.saveNewMember(cred.user!.uid, name: name, phone: phone, email: cred.user!.email ?? email);
    } finally {
      _signingUp = false;
    }
  }

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email);

  /// Sends a confirmation link to the new address. The email changes once they click it.
  Future<void> changeEmail(String email, String? password) async {
    final current = _auth.currentUser!;
    if (password != null) {
      await current.reauthenticateWithCredential(EmailAuthProvider.credential(email: current.email!, password: password));
    }
    await current.verifyBeforeUpdateEmail(email);
  }

  String? get authEmail => _auth.currentUser?.email;

  Future<void> logOut() async {
    _banSub?.cancel();
    _adminSub?.cancel();
    _stopMember();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _banSub?.cancel();
    _adminSub?.cancel();
    _memberSub?.cancel();
    super.dispose();
  }
}
