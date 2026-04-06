import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return UserModel.fromMap(doc.data()!, uid);
    } on FirebaseException catch (e) {
      debugPrint('Failed to load profile for $uid: ${e.message}');
      throw Exception('Unable to load your profile. Please try again.');
    }
  }

  Future<String?> getUserRole(String uid) async {
    final profile = await getUserProfile(uid);
    return profile?.role;
  }

  Future<UserModel?> adminLogin({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final profile = await getUserProfile(uid);
      if (profile == null) {
        await _auth.signOut();
        throw Exception('Profile not found. Please sign in again.');
      }

      if (profile.role != 'admin') {
        await _auth.signOut();
        throw Exception('Access denied. Not an admin account.');
      }

      return profile;
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  Future<UserModel?> studentLogin({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final profile = await getUserProfile(uid);
      if (profile == null) {
        await _auth.signOut();
        throw Exception('Profile not found. Please sign in again.');
      }

      return profile;
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  Future<UserModel?> studentRegister({
    required String name,
    required String studentId,
    required String department,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user!;
      await user.updateDisplayName(name);

      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        role: 'student',
        name: name,
        studentId: studentId,
        department: department,
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  Future<UserModel> createAdmin({
    required String name,
    required String email,
    required String password,
    required String currentAdminPassword,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Please sign in again before adding a new admin.');
    }

    final currentEmail = currentUser.email;
    if (currentEmail == null || currentEmail.trim().isEmpty) {
      throw Exception('Current admin email not available.');
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: currentEmail,
        password: currentAdminPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception('Current admin password is invalid.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final newUser = credential.user!;
      final userModel = UserModel(
        uid: newUser.uid,
        email: email.trim(),
        role: 'admin',
        name: name.trim(),
      );

      await _firestore.collection('users').doc(newUser.uid).set(userModel.toMap());

      await _auth.signOut();
      await _auth.signInWithEmailAndPassword(
        email: currentEmail,
        password: currentAdminPassword,
      );

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  Future<UserModel> promoteStudentToAdmin(String studentUid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(studentUid).get();
      if (!userDoc.exists) {
        throw Exception('User not found.');
      }

      final data = userDoc.data()!;
      final currentRole = data['role'] as String? ?? 'student';

      if (currentRole == 'admin') {
        throw Exception('This user is already an admin.');
      }

      await _firestore.collection('users').doc(studentUid).update({'role': 'admin'});

      return UserModel.fromMap({...data, 'role': 'admin'}, studentUid);
    } on FirebaseException catch (e) {
      debugPrint('Failed to promote student: ${e.message}');
      throw Exception('Unable to promote student. Please try again.');
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data == null || !doc.exists) {
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          role: 'student',
          name: user.displayName,
          photoUrl: user.photoURL,
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());
        return userModel;
      }

      return UserModel.fromMap(data, user.uid);
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    } on FirebaseException catch (e) {
      debugPrint('Google sign-in Firestore error: ${e.message}');
      throw Exception('Unable to load your Google profile. Please try again.');
    }
  }

  Future<UserModel> completeGoogleStudentProfile({
    required String uid,
    required String name,
    required String studentId,
    required String department,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      final userModel = UserModel(
        uid: uid,
        email: data['email'] as String? ?? currentUser?.email ?? '',
        role: data['role'] as String? ?? 'student',
        name: name.trim(),
        studentId: studentId.trim(),
        department: department.trim(),
        photoUrl: data['photoUrl'] as String? ?? currentUser?.photoURL,
      );

      await _firestore.collection('users').doc(uid).set({
        'uid': userModel.uid,
        'email': userModel.email,
        'role': userModel.role,
        'name': userModel.name,
        'studentId': userModel.studentId,
        'department': userModel.department,
        'photoUrl': userModel.photoUrl,
      }, SetOptions(merge: true));

      await currentUser?.updateDisplayName(name.trim());
      return userModel;
    } on FirebaseException catch (e) {
      debugPrint('Failed to complete Google profile for $uid: ${e.message}');
      throw Exception('Unable to save your profile. Please try again.');
    }
  }

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? studentId,
    String? department,
    List<String>? preferredCategories,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name.trim();
      if (studentId != null) updates['studentId'] = studentId.trim();
      if (department != null) updates['department'] = department.trim();
      if (preferredCategories != null) updates['preferredCategories'] = preferredCategories;

      if (updates.isEmpty) return;

      await _firestore.collection('users').doc(uid).update(updates);

      if (name != null && uid == _auth.currentUser?.uid) {
        await _auth.currentUser?.updateDisplayName(name.trim());
      }
    } on FirebaseException catch (e) {
      debugPrint('Failed to update profile for $uid: ${e.message}');
      throw Exception('Unable to update your profile right now.');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  Future<List<UserModel>> searchStudentsByName({
    required String query,
    Iterable<String> excludeUserIds = const [],
    int resultLimit = 10,
  }) async {
    final trimmed = _normalizeSearchText(query);
    if (trimmed.isEmpty) {
      return const [];
    }

    final tokens = trimmed
        .split(' ')
        .map(_normalizeSearchText)
        .where((token) => token.isNotEmpty)
        .toList();

    final excluded = excludeUserIds.map((id) => id.trim()).toSet();

    final docsById = <String, Map<String, dynamic>>{};

    // Prefer role-filtered query for compatibility with stricter rules.
    try {
      final filtered = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .limit(200)
          .get();
      for (final doc in filtered.docs) {
        docsById[doc.id] = doc.data();
      }
    } on FirebaseException {
      // Fall back to broader fetch for projects that allow full user reads.
    }

    if (docsById.isEmpty) {
      final snapshot = await _firestore.collection('users').limit(200).get();
      for (final doc in snapshot.docs) {
        docsById[doc.id] = doc.data();
      }
    }

    final ranked = <({UserModel user, int score})>[];

    for (final entry in docsById.entries) {
      final user = UserModel.fromMap(entry.value, entry.key);
      if (excluded.contains(user.uid)) continue;

      final normalizedRole = _normalizeSearchText(user.role);
      if (normalizedRole == 'admin') continue;

      final name = _normalizeSearchText(user.name);
      final email = _normalizeSearchText(user.email);
      final studentId = _normalizeSearchText(user.studentId);

      final allTokensMatch = tokens.every(
        (token) => _tokenMatchesAny(
          token: token,
          name: name,
          email: email,
          studentId: studentId,
        ),
      );
      if (!allTokensMatch) continue;

      var score = 0;
      if (name == trimmed) {
        score += 100;
      } else if (_startsWithNameWord(name, trimmed)) {
        score += 85;
      } else if (name.startsWith(trimmed)) {
        score += 70;
      } else if (name.contains(trimmed)) {
        score += 45;
      }

      if (email.startsWith(trimmed)) {
        score += 25;
      } else if (email.contains(trimmed)) {
        score += 12;
      }

      if (studentId.startsWith(trimmed)) {
        score += 20;
      } else if (studentId.contains(trimmed)) {
        score += 8;
      }

      // Prefer concise names when relevance is the same.
      score -= name.length ~/ 25;
      ranked.add((user: user, score: score));
    }

    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;

      final aName = _normalizeSearchText(a.user.name ?? a.user.email);
      final bName = _normalizeSearchText(b.user.name ?? b.user.email);
      return aName.compareTo(bName);
    });

    return ranked.take(resultLimit).map((item) => item.user).toList();
  }

  String _normalizeSearchText(String? input) {
    final raw = (input ?? '').trim().toLowerCase();
    if (raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _tokenMatchesAny({
    required String token,
    required String name,
    required String email,
    required String studentId,
  }) {
    if (token.isEmpty) return true;
    return name.contains(token) ||
        email.contains(token) ||
        studentId.contains(token);
  }

  bool _startsWithNameWord(String name, String query) {
    if (query.isEmpty || name.isEmpty) return false;
    return name.split(' ').any((part) => part.startsWith(query));
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        debugPrint('Unhandled FirebaseAuthException code: $code');
        return 'Something went wrong. Please try again.';
    }
  }
}
