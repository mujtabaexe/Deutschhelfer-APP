import 'dart:async';
import 'dart:io';

import 'package:deutschhelfer/app/app.dart';
import 'package:deutschhelfer/app/app_services.dart';
import 'package:deutschhelfer/config/app_config.dart';
import 'package:deutschhelfer/data/repositories/auth_repository.dart';
import 'package:deutschhelfer/data/repositories/guide_repository.dart';
import 'package:deutschhelfer/data/repositories/profile_repository.dart';
import 'package:deutschhelfer/domain/models/auth_session.dart';
import 'package:deutschhelfer/domain/models/guide.dart';
import 'package:deutschhelfer/domain/models/legal.dart';
import 'package:deutschhelfer/domain/models/user_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'community_fakes.dart';

export 'community_fakes.dart';

const verifiedStudent = AuthSession(
  uid: 'student-1',
  email: 'student@example.com',
  emailVerified: true,
  displayName: 'Ayesha Khan',
);

/// In-memory auth with a live session stream.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthSession? initial}) : _current = initial;

  final _changes = StreamController<AuthSession?>.broadcast();
  AuthSession? _current;

  final calls = <String>[];
  String? lastEmail;
  String? lastDisplayName;

  /// When set, requests wait on this completer instead of finishing at once.
  Completer<void>? pending;

  /// When set, requests fail with this failure.
  AuthFailure? failWith;

  /// Whether a successful sign-in produces a verified session.
  bool signInVerified = true;

  /// What [refreshSession] reports, and applies to the session.
  bool verifiedOnRefresh = false;

  void emit(AuthSession? session) {
    _current = session;
    _changes.add(session);
  }

  @override
  AuthSession? get currentSession => _current;

  @override
  Stream<AuthSession?> get sessionChanges async* {
    yield _current;
    yield* _changes.stream;
  }

  Future<void> _respond(String call) async {
    calls.add(call);
    if (pending != null) await pending!.future;
    if (failWith != null) throw AuthException(failWith!);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    await _respond('signIn');
    emit(
      AuthSession(
        uid: 'student-1',
        email: email,
        emailVerified: signInVerified,
        displayName: 'Ayesha Khan',
      ),
    );
  }

  @override
  Future<String> createAccount({
    required String displayName,
    required String email,
    required String password,
  }) async {
    lastDisplayName = displayName;
    lastEmail = email;
    await _respond('createAccount');
    emit(
      AuthSession(
        uid: 'new-1',
        email: email,
        emailVerified: false,
        displayName: displayName,
      ),
    );
    return 'new-1';
  }

  @override
  Future<void> sendPasswordReset({required String email}) {
    lastEmail = email;
    return _respond('sendPasswordReset');
  }

  @override
  Future<void> sendEmailVerification() => _respond('sendEmailVerification');

  @override
  Future<bool> refreshSession() async {
    await _respond('refreshSession');
    final current = _current;
    if (verifiedOnRefresh && current != null) {
      emit(
        AuthSession(
          uid: current.uid,
          email: current.email,
          emailVerified: true,
          displayName: current.displayName,
          role: current.role,
          isPremium: current.isPremium,
        ),
      );
    }
    return verifiedOnRefresh;
  }

  /// The password [reauthenticate] accepts.
  String validPassword = 'secret';

  @override
  Future<void> reauthenticate({required String password}) async {
    calls.add('reauthenticate');
    if (password != validPassword) {
      throw const AuthException(AuthFailure.invalidCredentials);
    }
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(null);
  }
}

/// In-memory profiles and account status.
class FakeProfileRepository implements ProfileRepository {
  final profiles = <String, String>{};
  final _status = StreamController<AccountStatus>.broadcast();
  AccountStatus status = AccountStatus.active;
  final _profileChanges = StreamController<String>.broadcast();
  bool failSaves = false;

  /// Accepted rules version per uid. Profiles without an entry count as
  /// accepted, unless [acceptByDefault] is false.
  final rulesVersions = <String, int>{};
  bool acceptByDefault = true;
  bool failAccept = false;

  void setStatus(AccountStatus next) {
    status = next;
    _status.add(next);
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    UserProfile? read() => profiles[uid] == null
        ? null
        : UserProfile(
            uid: uid,
            displayName: profiles[uid]!,
            rulesVersion:
                rulesVersions[uid] ??
                (acceptByDefault ? currentRulesVersion : 0),
          );
    yield read();
    yield* _profileChanges.stream.where((id) => id == uid).map((_) => read());
  }

  @override
  Future<void> ensureProfile({required String uid, String? displayName}) async {
    if (profiles.containsKey(uid)) return;
    profiles[uid] = displayName ?? fallbackDisplayName;
    _profileChanges.add(uid);
  }

  @override
  Future<void> saveDisplayName({
    required String uid,
    required String displayName,
    int? acceptedRulesVersion,
  }) async {
    if (failSaves) throw StateError('offline');
    profiles[uid] = displayName;
    if (acceptedRulesVersion != null) {
      rulesVersions[uid] = acceptedRulesVersion;
    }
    _profileChanges.add(uid);
  }

  @override
  Future<void> acceptRules({required String uid, required int version}) async {
    if (failAccept) throw StateError('offline');
    profiles.putIfAbsent(uid, () => fallbackDisplayName);
    rulesVersions[uid] = version;
    _profileChanges.add(uid);
  }

  @override
  Stream<AccountStatus> watchAccountStatus(String uid) async* {
    yield status;
    yield* _status.stream;
  }
}

/// Serves the real bundled guide JSON without asset I/O, which does not
/// complete under the widget-test fake clock.
class InMemoryGuideRepository implements GuideRepository {
  InMemoryGuideRepository({this.premiumBodies = const {}});

  static final GuideLibrary bundled = parseGuideLibrary(
    File('assets/content/guide.json').readAsStringSync(),
  );

  final Map<String, List<GuideBlock>> premiumBodies;
  PremiumContentFailure? premiumFailure;

  @override
  Future<GuideLibrary> loadLibrary() => SynchronousFuture(bundled);

  @override
  Future<GuideArticle> loadPremiumBody(GuideArticle teaser) async {
    if (premiumFailure != null) {
      throw PremiumContentException(premiumFailure!);
    }
    final blocks = premiumBodies[teaser.id];
    if (blocks == null) {
      throw const PremiumContentException(PremiumContentFailure.notFound);
    }
    return teaser.withBody(blocks: blocks, sources: const []);
  }
}

AppServices fakeServices({
  FakeAuthRepository? auth,
  FakeProfileRepository? profiles,
  GuideRepository? guide,
  FakeGroupRepository? groups,
  FakeConversationRepository? conversations,
  FakeReportRepository? reports,
  FakeAccountRepository? accounts,
  FakePushRepository? push,
}) => AppServices(
  authRepository: auth ?? FakeAuthRepository(),
  profileRepository: profiles ?? FakeProfileRepository(),
  guideRepository: guide ?? InMemoryGuideRepository(),
  groupRepository: groups ?? FakeGroupRepository(),
  conversationRepository: conversations ?? FakeConversationRepository(),
  reportRepository: reports ?? FakeReportRepository(),
  accountRepository: accounts ?? FakeAccountRepository(),
  pushRepository: push ?? FakePushRepository(),
);

/// Ticks the community rules checkbox on the create-account form.
Future<void> tickRulesCheckbox(WidgetTester tester) async {
  final box = find.byType(CheckboxListTile);
  await tester.ensureVisible(box);
  await tester.tap(box);
  await tester.pump();
}

/// Pumps the full app at a given phone size and text scale.
Future<void> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? authRepository,
  FakeProfileRepository? profileRepository,
  AppServices? services,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
  AppConfig config = const AppConfig(environment: AppEnvironment.development),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    DeutschhelferApp(
      config: config,
      services:
          services ??
          fakeServices(auth: authRepository, profiles: profileRepository),
    ),
  );
  await tester.pumpAndSettle();
}
