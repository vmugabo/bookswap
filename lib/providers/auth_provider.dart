import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:google_sign_in/google_sign_in.dart';

import '../services/firebase_service.dart';
import '../models/user_profile.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  if (!FirebaseService.initialized) {
    // Fail fast when code tries to use FirebaseAuth before initialization.
    // Upstream callers should use `FirebaseService.initialized` or
    // `authStateChangesProvider` to guard UI paths during start-up.
    throw StateError('Firebase has not been initialized');
  }
  return FirebaseService.auth;
});

/// Expose auth state changes. If Firebase hasn't been initialized yet (e.g.
/// during local dev without FlutterFire config), expose a single `null` value
/// so UI can run without crashing. This avoids calling `FirebaseAuth.instance`
/// before `Firebase.initializeApp()` completed.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  if (!FirebaseService.initialized) return Stream.value(null);
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));

/// Stream provider that exposes the current user's profile document from Firestore.
final userProfileProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  // If no signed-in user, emit null
  final user = authState.asData?.value;
  if (user == null) return Stream.value(null);

  return FirebaseService.firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) => snap.exists && snap.data() != null
          ? UserProfile.fromMap(snap.data() as Map<String, dynamic>)
          : null);
});

/// Provides a one-shot fetch of any user's profile by uid.
final userProfileByIdProvider =
    FutureProvider.family<UserProfile?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  if (!FirebaseService.initialized) return null;
  final doc =
      await FirebaseService.firestore.collection('users').doc(uid).get();
  if (!doc.exists || doc.data() == null) return null;
  return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
});

class AuthService {
  final Ref _ref;
  AuthService(this._ref);
  FirebaseAuth get _auth => _ref.read(firebaseAuthProvider);
  FirebaseFirestore get _firestore => FirebaseService.firestore;

  Future<UserCredential> signUp(
      String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user?.updateDisplayName(displayName);
    await cred.user?.sendEmailVerification();
    // create profile doc
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': cred.user!.email,
      'displayName': displayName,
      'notifications': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return cred;
  }

  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    // Ensure a Firestore profile document exists for this user after sign-in.
    await ensureProfileExists();
    return cred;
  }

  Future<void> signOut() async => _auth.signOut();

  /// Unified sign out: signs out from Firebase and Google (on mobile)
  Future<void> signOutAll() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        // ignore
      }
    }
  }

  /// Upload a profile picture from a File (mobile). Returns the download URL.
  Future<String> uploadProfilePictureFile(dynamic imageFile) async {
    final user = _auth.currentUser;
    if (user == null)
      throw FirebaseAuthException(
          code: 'no-user', message: 'No signed-in user');
    final uid = user.uid;
    final id = uid;
    final ref =
        FirebaseService.storage.ref().child('profile_pics/$uid/$id.jpg');
    final metadata = fb_storage.SettableMetadata(contentType: 'image/jpeg');
    await ref.putFile(imageFile, metadata);
    final url = await ref.getDownloadURL();
    // Update user's photoURL and Firestore profile
    await user.updatePhotoURL(url);
    await _firestore.collection('users').doc(uid).update({'imageUrl': url});
    return url;
  }

  /// Upload a profile picture from bytes (web). Returns the download URL.
  Future<String> uploadProfilePictureBytes(Uint8List bytes,
      {String contentType = 'image/jpeg'}) async {
    final user = _auth.currentUser;
    if (user == null)
      throw FirebaseAuthException(
          code: 'no-user', message: 'No signed-in user');
    final uid = user.uid;
    final id = uid;
    final ref =
        FirebaseService.storage.ref().child('profile_pics/$uid/$id.jpg');
    final metadata = fb_storage.SettableMetadata(contentType: contentType);
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    await user.updatePhotoURL(url);
    await _firestore.collection('users').doc(uid).update({'imageUrl': url});
    return url;
  }

  Future<void> sendEmailVerification() async =>
      _auth.currentUser?.sendEmailVerification();

  /// Update the Firebase user's display name and the Firestore profile doc.
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null)
      throw FirebaseAuthException(
          code: 'no-user', message: 'No signed-in user');
    await user.updateDisplayName(displayName);
    await _firestore
        .collection('users')
        .doc(user.uid)
        .update({'displayName': displayName});
  }

  /// Toggle notifications preference in the Firestore user profile.
  Future<void> updateNotifications(bool enabled) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null)
      throw FirebaseAuthException(
          code: 'no-user', message: 'No signed-in user');
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'notifications': enabled});
  }

  /// Send a password reset email to the given email address.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign in with Google (supports web and mobile flows). Creates a Firestore
  /// profile document for new users.
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(googleProvider);
      final user = cred.user;
      if (user != null) {
        final doc = _firestore.collection('users').doc(user.uid);
        final snap = await doc.get();
        if (!snap.exists) {
          await doc.set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? '',
            'notifications': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        // make sure the profile doc exists and is canonical
        await ensureProfileExists();
      }
      return cred;
    } else {
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null)
        throw FirebaseAuthException(
            code: 'cancelled', message: 'Sign in aborted');
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken);
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user != null) {
        final doc = _firestore.collection('users').doc(user.uid);
        final snap = await doc.get();
        if (!snap.exists) {
          await doc.set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName ?? '',
            'notifications': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        // ensure the profile exists
        await ensureProfileExists();
      }
      return cred;
    }
  }

  /// Ensure the user's Firestore profile document exists. Creates it from
  /// the FirebaseAuth user info if missing.
  Future<void> ensureProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = _firestore.collection('users').doc(user.uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'imageUrl': user.photoURL ?? '',
        'notifications': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
