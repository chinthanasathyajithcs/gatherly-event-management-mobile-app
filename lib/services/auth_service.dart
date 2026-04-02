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

      if (profile.role == 'admin') {
        await _auth.signOut();
        throw Exception('Please use the Admin login instead.');
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

      final role = data['role'];
      if (role == 'admin') {
        await _auth.signOut();
        await _googleSignIn.signOut();
        throw Exception('Admin accounts cannot use Google Sign-In.');
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
