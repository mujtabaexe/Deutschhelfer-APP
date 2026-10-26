import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/push_repository.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/legal.dart';
import '../domain/models/user_profile.dart';

enum SessionStatus {
  initializing,
  signedOut,
  unverified,
  restricted,

  /// Signed in and verified, but has not accepted the current community
  /// rules, for example after an interrupted sign-up or a rules update.
  needsRules,
  active,
}

/// Combines the auth session with the server-owned account status and drives
/// route guards.
///
/// Guards only decide which screen to show. Firestore Rules enforce the same
/// conditions on every request.
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthRepository authRepository,
    required ProfileRepository profileRepository,
    PushRepository pushRepository = const UnsupportedPushRepository(),
  }) : _auth = authRepository,
       _profiles = profileRepository,
       _push = pushRepository;

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final PushRepository _push;

  StreamSubscription<AuthSession?>? _sessionSub;
  StreamSubscription<AccountStatus>? _statusSub;
  StreamSubscription<UserProfile?>? _profileSub;

  AuthSession? _session;
  AccountStatus? _accountStatus;
  UserProfile? _profile;
  bool _sawAuthState = false;
  bool _disposed = false;

  /// Set while [signOut] already unregisters push for this uid.
  String? _forgettingUid;

  AuthSession? get session => _session;
  UserProfile? get profile => _profile;
  AccountStatus get accountStatus => _accountStatus ?? AccountStatus.active;

  /// Display name from the profile, falling back to the auth record.
  String get displayName =>
      _profile?.displayName ?? _session?.displayName ?? fallbackDisplayName;

  SessionStatus get status {
    if (!_sawAuthState) return SessionStatus.initializing;
    final session = _session;
    if (session == null) return SessionStatus.signedOut;
    if (_accountStatus == null) return SessionStatus.initializing;
    if (_accountStatus != AccountStatus.active) {
      return SessionStatus.restricted;
    }
    if (!session.emailVerified) return SessionStatus.unverified;
    final profile = _profile;
    if (profile != null && profile.rulesVersion < currentRulesVersion) {
      return SessionStatus.needsRules;
    }
    return SessionStatus.active;
  }

  void start() {
    _sessionSub ??= _auth.sessionChanges.listen(
      _onSession,
      onError: (Object _) => _onSession(null),
    );
  }

  void _onSession(AuthSession? next) {
    final previousUid = _session?.uid;
    _session = next;
    _sawAuthState = true;

    if (next?.uid != previousUid) {
      // Sessions also end without signOut(): revoked or disabled accounts,
      // or a sign-out from the verify screen. The next account on this
      // device must not get the previous one's alerts.
      if (previousUid != null && previousUid != _forgettingUid) {
        unawaited(_push.forget(previousUid));
      }
      unawaited(_statusSub?.cancel());
      unawaited(_profileSub?.cancel());
      _statusSub = null;
      _profileSub = null;
      _accountStatus = null;
      _profile = null;
      if (next != null) _watchAccount(next);
    }
    _notify();
  }

  void _watchAccount(AuthSession session) {
    _statusSub = _profiles
        .watchAccountStatus(session.uid)
        .listen(
          (status) {
            _accountStatus = status;
            _notify();
          },
          // Reading our own restriction doc should not fail. If it does,
          // show the app; the server still enforces restrictions.
          onError: (Object _) {
            _accountStatus = AccountStatus.active;
            _notify();
          },
        );

    var ensured = false;
    _profileSub = _profiles.watchProfile(session.uid).listen((profile) {
      _profile = profile;
      if (profile == null && !ensured) {
        ensured = true;
        unawaited(
          _profiles
              .ensureProfile(uid: session.uid, displayName: session.displayName)
              .catchError((Object _) {}),
        );
      }
      _notify();
    }, onError: (Object _) {});
  }

  /// Records acceptance of the current community rules. The profile
  /// listener then moves the session on.
  Future<void> acceptRules() async {
    final uid = _session?.uid;
    if (uid == null) return;
    await _profiles.acceptRules(uid: uid, version: currentRulesVersion);
  }

  /// Unregisters this device from push first, while the user can still
  /// write their own data. That step is best effort.
  Future<void> signOut() async {
    final uid = _session?.uid;
    if (uid != null) {
      _forgettingUid = uid;
      // Bounded even if a repository misbehaves.
      await _push
          .forget(uid)
          .timeout(const Duration(seconds: 8), onTimeout: () {})
          .catchError((Object _) {});
    }
    await _auth.signOut();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sessionSub?.cancel());
    unawaited(_statusSub?.cancel());
    unawaited(_profileSub?.cancel());
    super.dispose();
  }
}
