import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/app_config.dart';
import '../config/firebase_config.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/conversation_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/guide_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/push_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/unconfigured_community.dart';

/// Every repository the app uses, created once at startup and passed down
/// through constructors.
class AppServices {
  const AppServices({
    required this.authRepository,
    required this.profileRepository,
    required this.guideRepository,
    this.groupRepository = const UnconfiguredGroupRepository(),
    this.conversationRepository = const UnconfiguredConversationRepository(),
    this.reportRepository = const UnconfiguredReportRepository(),
    this.accountRepository = const UnconfiguredAccountRepository(),
    this.pushRepository = const UnsupportedPushRepository(),
  });

  /// Services for builds with no Firebase project. Nobody can sign in.
  factory AppServices.unconfigured() => AppServices(
    authRepository: const UnconfiguredAuthRepository(),
    profileRepository: const UnconfiguredProfileRepository(),
    guideRepository: BundledGuideRepository(),
  );

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final GuideRepository guideRepository;
  final GroupRepository groupRepository;
  final ConversationRepository conversationRepository;
  final ReportRepository reportRepository;
  final AccountRepository accountRepository;
  final PushRepository pushRepository;
}

/// Must match the region in firebase/functions/index.js.
const functionsRegion = 'asia-southeast1';

/// Initializes Firebase when configured and builds the services.
Future<AppServices> createServices(
  AppConfig app,
  FirebaseConfig? firebase,
) async {
  if (firebase == null) {
    if (app.isProduction) {
      throw StateError('Production builds need a Firebase configuration.');
    }
    return AppServices.unconfigured();
  }

  final firebaseApp = await Firebase.initializeApp(options: firebase.options);
  final auth = FirebaseAuth.instanceFor(app: firebaseApp);
  final db = FirebaseFirestore.instanceFor(app: firebaseApp);
  final functions = FirebaseFunctions.instanceFor(
    app: firebaseApp,
    region: functionsRegion,
  );

  final host = firebase.emulatorHost;
  if (host != null) {
    await auth.useAuthEmulator(host, 9099);
    db.useFirestoreEmulator(host, 8080);
    functions.useFunctionsEmulator(host, 5001);
  } else {
    // App Check proves requests come from this app on a genuine device.
    // Debug builds print a debug token to register in the Firebase console.
    await FirebaseAppCheck.instanceFor(app: firebaseApp).activate(
      providerAndroid: app.isProduction
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
    );
  }

  return AppServices(
    authRepository: FirebaseAuthRepository(auth),
    profileRepository: FirestoreProfileRepository(db),
    guideRepository: BundledGuideRepository(firestore: db),
    groupRepository: FirestoreGroupRepository(db),
    conversationRepository: FirestoreConversationRepository(db),
    reportRepository: FirestoreReportRepository(db),
    accountRepository: FunctionsAccountRepository(functions),
    // FCM has no emulator, so emulator builds do not register devices.
    pushRepository: host == null
        ? FirebasePushRepository(db, FirebaseMessaging.instance)
        : const UnsupportedPushRepository(),
  );
}
