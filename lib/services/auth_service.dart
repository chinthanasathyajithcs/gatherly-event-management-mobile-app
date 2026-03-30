import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // ← add this
import '../models/user_model.dart';
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Get current user ────────────────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Get user role from Firestore ────────────────────────────────────────────
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Admin Login (email + password only) ─────────────────────────────────────
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
      final role = await getUserRole(uid);

      // Make sure this user is actually an admin
      if (role != 'admin') {
        await _auth.signOut();
        throw Exception('Access denied. Not an admin account.');
      }

      final doc = await _firestore.collection('users').doc(uid).get();
      return UserModel.fromMap(doc.data()!, uid);
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  // ── Student Login (email + password) ────────────────────────────────────────
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
      final role = await getUserRole(uid);

      if (role == 'admin') {
        await _auth.signOut();
        throw Exception('Please use the Admin login instead.');
      }

      final doc = await _firestore.collection('users').doc(uid).get();
      return UserModel.fromMap(doc.data()!, uid);
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  // ── Student Register (email + password) ─────────────────────────────────────
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

      // Update display name
      await user.updateDisplayName(name);

      // Save to Firestore
      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        role: 'student',
        name: name,
        studentId: studentId,
        department: department,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  // ── Google Sign-In (students only) ──────────────────────────────────────────
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Check if user already exists in Firestore
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // New user — save to Firestore as student
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
      } else {
        // Existing user
        final role = doc.data()?['role'];
        if (role == 'admin') {
          await _auth.signOut();
          await _googleSignIn.signOut();
          throw Exception('Admin accounts cannot use Google Sign-In.');
        }
        return UserModel.fromMap(doc.data()!, user.uid);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Password Reset ───────────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseErrorMessage(e.code));
    }
  }

  // ── Firebase error messages ──────────────────────────────────────────────────
  String _firebaseErrorMessage(String code) {
    switch (code) {
      // ✅ FIXED: Modern Firebase SDK uses 'invalid-credential' instead of
      // 'wrong-password' or 'user-not-found' for security reasons.
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
      // ✅ FIXED: Catches any other unhandled codes with the actual code
      // in debug output so you can identify new cases easily.
      default:
        debugPrint('Unhandled FirebaseAuthException code: $code');
        return 'Something went wrong. Please try again.';
    }
  }
}