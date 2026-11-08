import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'models.dart';
import 'store.dart';

/// Email/password accounts + Firestore sync for one user's own data.
///
/// Layout in Firestore (rules only let the owner read/write):
///   users/{uid}/txns/{txnId}      one document per transaction
///   users/{uid}/meta/settings     currency, budgets, recurring rules
///
/// Strategy: local-first. Every change is saved on the phone immediately and
/// queued; sync pulls newer remote items, merges (newest edit wins) and then
/// pushes our queued changes.
class CloudService extends ChangeNotifier {
  final AppStore store;
  CloudService(this.store);

  bool available = false; // false until Firebase is configured
  User? user;
  bool syncing = false;
  DateTime? lastSync;
  String? error;
  Timer? _debounce;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(user!.uid);

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      available = true;
    } catch (_) {
      available = false;
      notifyListeners();
      return;
    }
    user = FirebaseAuth.instance.currentUser;
    store.onLocalChange = _scheduleSync;
    notifyListeners();
    if (user != null) unawaited(syncNow());
  }

  void _scheduleSync() {
    if (!available || user == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  // ---------------------------------------------------------------- auth
  /// Returns an error message, or null on success.
  Future<String?> signIn(String email, String password) async {
    try {
      final c = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      user = c.user;
      return _afterAuth();
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> register(String email, String password) async {
    try {
      final c = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email.trim(), password: password);
      user = c.user;
      try {
        await user?.sendEmailVerification();
      } catch (_) {}
      return _afterAuth();
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> _afterAuth() async {
    await store.markAllDirty(); // upload what is already on this phone
    notifyListeners();
    unawaited(syncNow());
    return null;
  }

  Future<String?> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return 'Could not send the reset email.';
    }
  }

  Future<void> resendVerification() async {
    try {
      await user?.sendEmailVerification();
    } catch (_) {}
  }

  /// Signs out. [removeLocalData] also clears this phone's copy.
  Future<void> signOut({required bool removeLocalData}) async {
    await syncNow(); // push anything pending first
    await FirebaseAuth.instance.signOut();
    user = null;
    if (removeLocalData) {
      await store.wipeLocalOnly();
    }
    notifyListeners();
  }

  /// Deletes cloud data and the account itself. Local data stays.
  Future<String?> deleteAccount() async {
    final u = user;
    if (u == null) return 'You are not signed in.';
    try {
      final base = _userDoc;
      while (true) {
        final snap = await base.collection('txns').limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      await base.collection('meta').doc('settings').delete();
      await u.delete();
      user = null;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'For security, sign out and sign in again, then retry.';
      }
      return _authMessage(e);
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not delete your data.';
    } catch (_) {
      return 'Could not delete your account.';
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks wrong.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try signing in.';
      case 'weak-password':
        return 'Use a password with at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }

  // ---------------------------------------------------------------- sync
  Future<void> syncNow() async {
    final u = user;
    if (!available || u == null || syncing) return;
    syncing = true;
    error = null;
    notifyListeners();
    try {
      try {
        await u.reload();
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {}

      final base = _userDoc;

      // 1. Pull anything newer than last time (10 min margin for clock skew).
      final last = store.lastPull(u.uid);
      Query<Map<String, dynamic>> q = base.collection('txns');
      if (last > 0) q = q.where('u', isGreaterThan: last - 600000);
      final snap = await q.get();
      final remote = snap.docs
          .map((d) => Txn.fromJson({...d.data(), 'id': d.id}))
          .toList();
      await store.mergeTxns(remote);
      var maxU = last;
      for (final r in remote) {
        maxU = math.max(maxU, r.updatedAt);
      }
      await store.setLastPull(u.uid, maxU);

      final sdoc = await base.collection('meta').doc('settings').get();
      if (sdoc.exists && sdoc.data() != null) {
        await store.applySettingsJson(sdoc.data()!);
      }

      // 2. Push our queued changes.
      final dirty = store.dirtyTxns;
      for (var i = 0; i < dirty.length; i += 400) {
        final chunk = dirty.sublist(i, math.min(i + 400, dirty.length));
        final batch = _db.batch();
        for (final t in chunk) {
          batch.set(base.collection('txns').doc(t.id), t.toJson());
        }
        await batch.commit();
        await store.markPushed(chunk.map((t) => t.id));
      }
      if (store.settingsDirty) {
        await base.collection('meta').doc('settings').set(store.settingsJson());
        await store.markPushed(const [], settings: true);
      }
      lastSync = DateTime.now();
    } on FirebaseException catch (e) {
      error = e.code == 'unavailable' ? 'Offline. Will retry.' : (e.message ?? e.code);
    } catch (_) {
      error = 'Sync failed. Will retry.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
