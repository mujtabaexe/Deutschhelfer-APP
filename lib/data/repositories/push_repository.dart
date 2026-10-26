import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Push notifications for new direct messages and moderation decisions.
///
/// A device is registered as `users/{uid}/devices/{token}`. The server sends
/// sender names only, never message text, and removes tokens FCM rejects.
///
/// This uses FCM registration tokens. firebase_messaging 17 deprecates them
/// in favour of installation ids (`register()` / `onRegistered`); moving over
/// waits until that flow can be checked on a real device. See
/// docs/open-questions.md.
abstract interface class PushRepository {
  /// False in builds that cannot receive pushes, such as emulator builds.
  bool get isSupported;

  /// Whether this device currently receives notifications for [uid].
  Future<bool> isEnabled(String uid);

  /// Asks for permission if needed, then registers this device. Returns false
  /// when the user declined.
  Future<bool> enable(String uid);

  /// Stops notifications to this device for [uid].
  Future<void> disable(String uid);

  /// Called before sign-out: unregisters and invalidates this device's token,
  /// so the next account on this device never gets the previous one's alerts.
  Future<void> forget(String uid);

  /// Taps on notifications, as a data payload, including the one that
  /// launched the app.
  Stream<Map<String, String>> get openedMessages;
}

/// Device token ids are written by clients, so check them before use.
final _tokenPattern = RegExp(r'^[A-Za-z0-9_:\-]{20,512}$');

class FirebasePushRepository implements PushRepository {
  FirebasePushRepository(this._db, this._messaging);

  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _refreshSub;

  @override
  bool get isSupported => true;

  DocumentReference<Map<String, dynamic>> _device(String uid, String token) =>
      _db.collection('users').doc(uid).collection('devices').doc(token);

  Future<String?> _token() async {
    // ignore: deprecated_member_use
    final token = await _messaging.getToken();
    return token != null && _tokenPattern.hasMatch(token) ? token : null;
  }

  Future<void> _register(String uid, String token) => _device(uid, token).set({
    'token': token,
    'platform': 'android',
    'updatedAt': FieldValue.serverTimestamp(),
  });

  bool _allowed(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  @override
  Future<bool> isEnabled(String uid) async {
    if (!_allowed(await _messaging.getNotificationSettings())) return false;
    final token = await _token();
    if (token == null) return false;
    final enabled = (await _device(uid, token).get()).exists;
    if (enabled) _followRefresh(uid, token);
    return enabled;
  }

  @override
  Future<bool> enable(String uid) async {
    if (!_allowed(await _messaging.requestPermission())) return false;
    final token = await _token();
    if (token == null) return false;
    await _register(uid, token);
    _followRefresh(uid, token);
    return true;
  }

  /// FCM may rotate the token. Move the registration with it while the app
  /// runs; a rotation while closed is cleaned up by the server.
  void _followRefresh(String uid, String token) {
    unawaited(_refreshSub?.cancel());
    var current = token;
    // ignore: deprecated_member_use
    _refreshSub = _messaging.onTokenRefresh.listen((next) async {
      if (!_tokenPattern.hasMatch(next) || next == current) return;
      final previous = current;
      current = next;
      try {
        await _register(uid, next);
        await _device(uid, previous).delete();
      } catch (_) {
        // Best effort; the server prunes tokens FCM rejects.
      }
    });
  }

  @override
  Future<void> disable(String uid) async {
    unawaited(_refreshSub?.cancel());
    _refreshSub = null;
    final token = await _token();
    if (token != null) await _device(uid, token).delete();
  }

  /// Signing out must not depend on the network: a Firestore write only
  /// completes once the server confirms it, so nothing here waits on one.
  static const _quick = Duration(seconds: 5);

  @override
  Future<void> forget(String uid) async {
    unawaited(_refreshSub?.cancel());
    _refreshSub = null;
    try {
      final token = await _token().timeout(_quick);
      if (token != null) {
        // Not awaited. If it never reaches the server, invalidating the
        // token below makes FCM reject it, and the server then prunes it.
        unawaited(_device(uid, token).delete().catchError((Object _) {}));
      }
    } catch (_) {}
    try {
      // ignore: deprecated_member_use
      await _messaging.deleteToken().timeout(_quick);
    } catch (_) {}
  }

  @override
  Stream<Map<String, String>> get openedMessages async* {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) yield _strings(initial.data);
    yield* FirebaseMessaging.onMessageOpenedApp.map((m) => _strings(m.data));
  }

  static Map<String, String> _strings(Map<String, dynamic> data) => {
    for (final entry in data.entries)
      if (entry.value is String) entry.key: entry.value as String,
  };
}

/// For builds without push support. Nothing is registered or received.
class UnsupportedPushRepository implements PushRepository {
  const UnsupportedPushRepository();

  @override
  bool get isSupported => false;

  @override
  Future<bool> isEnabled(String uid) async => false;

  @override
  Future<bool> enable(String uid) async => false;

  @override
  Future<void> disable(String uid) async {}

  @override
  Future<void> forget(String uid) async {}

  @override
  Stream<Map<String, String>> get openedMessages => const Stream.empty();
}
