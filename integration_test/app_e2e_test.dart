// End-to-end journeys on an Android emulator against the Firebase Emulator
// Suite. Nothing here touches a real project. See
// docs/release/06-device-test-results.md for how to run it:
//
//   cd firebase && npx firebase emulators:start --only auth,firestore,functions --project demo-deutschhelfer
//   flutter run -d emulator-5554 -t integration_test/app_e2e_test.dart --dart-define-from-file=config/emulator.json
//
// `flutter run` on a test file runs it live on the device. The
// integration_test plugin is not used: it does not build with this
// project's Android Gradle settings (see 06-device-test-results.md).
//
// Real email delivery, App Check and push cannot be tested this way.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:deutschhelfer/app/app.dart';
import 'package:deutschhelfer/app/app_services.dart';
import 'package:deutschhelfer/config/app_config.dart';
import 'package:deutschhelfer/config/firebase_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _project = 'demo-deutschhelfer';
const _password = 'e2e-Passw0rd';

const _host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
final _run = DateTime.now().millisecondsSinceEpoch;
final _ownerEmail = 'owner-$_run@example.test';
final _studentEmail = 'student-$_run@example.test';
final _groupName = 'E2E Visa $_run'.substring(0, 18);

late AppConfig _config;
late AppServices _services;

// ---------- Emulator REST helpers (test setup only) ----------

/// The test binding replaces HttpClient with a stub that answers 400. These
/// setup calls need the real one. The app itself talks to Firebase through
/// the native SDKs, which the stub does not affect.
class _RealHttp extends HttpOverrides {}

HttpClient _client() =>
    HttpOverrides.runWithHttpOverrides(HttpClient.new, _RealHttp());

Future<Map<String, dynamic>> _rest(
  String method,
  String url, {
  Object? body,
  bool admin = false,
}) async {
  final client = _client();
  try {
    final request = await client.openUrl(method, Uri.parse(url));
    request.headers.contentType = ContentType.json;
    // The emulators accept "owner" as an admin credential.
    if (admin) request.headers.set('Authorization', 'Bearer owner');
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 300) {
      throw StateError('$method $url -> ${response.statusCode}: $text');
    }
    return text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

String get _auth => 'http://$_host:9099';
String get _firestore =>
    'http://$_host:8080/v1/projects/$_project/databases/(default)/documents';

/// Creates a verified owner, as scripts/set-owner.mjs would.
Future<void> _createOwner() async {
  final created = await _rest(
    'POST',
    '$_auth/identitytoolkit.googleapis.com/v1/accounts:signUp?key=ADemoEmulatorOnlyKeyNotARealSecret00000',
    body: {'email': _ownerEmail, 'password': _password},
  );
  final uid = created['localId'] as String;
  await _rest(
    'POST',
    '$_auth/identitytoolkit.googleapis.com/v1/projects/$_project/accounts:update',
    admin: true,
    body: {
      'localId': uid,
      'emailVerified': true,
      'customAttributes': jsonEncode({'role': 'owner'}),
    },
  );
  await _rest(
    'PATCH',
    '$_firestore/staff/$uid',
    admin: true,
    body: {
      'fields': {
        'role': {'stringValue': 'owner'},
      },
    },
  );
}

/// Opens the newest verification link the Auth emulator "sent" to [email].
Future<void> _confirmEmail(String email) async {
  final codes = await _rest(
    'GET',
    '$_auth/emulator/v1/projects/$_project/oobCodes',
  );
  final link =
      (codes['oobCodes'] as List).cast<Map<String, dynamic>>().lastWhere(
            (c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL',
          )['oobLink']
          as String;
  final client = _client();
  try {
    final response = await (await client.getUrl(
      Uri.parse(link.replaceFirst('127.0.0.1', _host)),
    )).close();
    await response.drain<void>();
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>> _lookupUser(String email) async {
  final result = await _rest(
    'POST',
    '$_auth/identitytoolkit.googleapis.com/v1/projects/$_project/accounts:lookup',
    admin: true,
    body: {
      'email': [email],
    },
  );
  return (result['users'] as List).single as Map<String, dynamic>;
}

// ---------- UI helpers ----------

Finder _field(String label) => find.widgetWithText(TextField, label);

/// Pumps until [finder] matches, because real network calls do not settle.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  // Show what is on screen instead, to make failures diagnosable.
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(45)
      .join(' | ');
  fail('Timed out waiting for $finder. On screen: $texts');
}

/// Snackbars sit over the bottom of the screen, where real users can still
/// reach the buttons beside them; synthetic taps cannot.
Future<void> _clearSnackBars(WidgetTester tester) async {
  for (final element in find.byType(ScaffoldMessenger).evaluate()) {
    ((element as StatefulElement).state as ScaffoldMessengerState)
        .clearSnackBars();
  }
  final end = DateTime.now().add(const Duration(seconds: 8));
  do {
    await tester.pump(const Duration(milliseconds: 200));
  } while (find.byType(SnackBar).evaluate().isNotEmpty &&
      DateTime.now().isBefore(end));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await _clearSnackBars(tester);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  await _waitFor(tester, _field(label));
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _startApp(WidgetTester tester) async {
  // Lay out at the phone's real size, not the 800x600 test surface.
  final display = tester.view.display;
  tester.view.physicalSize = display.size;
  tester.view.devicePixelRatio = display.devicePixelRatio;
  await tester.pumpWidget(
    DeutschhelferApp(config: _config, services: _services),
  );
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _signIn(WidgetTester tester, String email) async {
  await _tap(tester, find.widgetWithText(OutlinedButton, 'Sign in'));
  await _type(tester, 'Email', email);
  await _type(tester, 'Password', _password);
  await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
}

Future<void> _signOut(WidgetTester tester) async {
  await _tap(tester, find.byIcon(Icons.person_outline));
  await _tap(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
  await _tap(tester, find.widgetWithText(FilledButton, 'Sign out'));
  await _waitFor(tester, find.text('Your path to studying in Germany'));
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (_host.isEmpty) {
      fail('Run with --dart-define-from-file=config/emulator.json');
    }
    _config = AppConfig.fromEnvironment();
    _services = await createServices(
      _config,
      FirebaseConfig.fromEnvironment(_config),
    );
    // Start from empty emulators, so earlier runs cannot affect this one.
    await _rest(
      'DELETE',
      'http://$_host:8080/emulator/v1/projects/$_project/databases/(default)/documents',
    );
    await _rest('DELETE', '$_auth/emulator/v1/projects/$_project/accounts');
    await _createOwner();
  });

  testWidgets('owner creates a group', (tester) async {
    await _services.authRepository.signOut();
    await _startApp(tester);
    await _signIn(tester, _ownerEmail);

    // A fresh profile has not accepted the community rules yet. Depending on
    // how fast the profile loads, sign-in lands on the gate or on the guide,
    // where groups ask for acceptance first.
    final gate = find.text('I accept the rules');
    await _waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is NavigationBar || (w is Text && w.data == 'I accept the rules'),
      ),
    );
    if (gate.evaluate().isEmpty) {
      await _tap(tester, find.byIcon(Icons.groups_outlined));
    }
    await _tap(tester, gate);
    await _waitFor(tester, find.byType(NavigationBar));

    await _tap(tester, find.byIcon(Icons.groups_outlined));
    await _tap(tester, find.text('New group'));
    await _type(tester, 'Group name', _groupName);
    await _tap(tester, find.widgetWithText(FilledButton, 'Create group'));
    await _waitFor(tester, find.text(_groupName));
    await _signOut(tester);
  });

  testWidgets('a student registers, verifies, reads, joins and chats', (
    tester,
  ) async {
    // Independent of how the owner test ended.
    await _services.authRepository.signOut();
    await _startApp(tester);

    // Registration refuses an unaccepted form, then succeeds.
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));
    await _type(tester, 'Display name', 'E2E Student');
    await _type(tester, 'Email', _studentEmail);
    await _type(tester, 'Password', _password);
    await _type(tester, 'Confirm password', _password);
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));
    await _waitFor(
      tester,
      find.text('Accept the community rules to create an account.'),
    );
    await _tap(tester, find.byType(CheckboxListTile));
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));

    // Unverified accounts are held on the verify screen.
    await _waitFor(tester, find.text('Confirm your email'));
    await _tap(tester, find.text('I have confirmed my email'));
    await _waitFor(tester, find.textContaining('not confirmed yet'));

    await _confirmEmail(_studentEmail);
    await _tap(tester, find.text('I have confirmed my email'));
    await _waitFor(tester, find.byType(NavigationBar));

    // Guide: open an article and come back.
    await _tap(
      tester,
      find.text('Your roadmap from Pakistan to a German university'),
    );
    await _waitFor(tester, find.text('The usual order'));
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));

    // Groups: join the owner's group and chat.
    await _tap(tester, find.byIcon(Icons.groups_outlined));
    await _tap(tester, find.text(_groupName));
    await _tap(tester, find.text('Join group'));
    await _waitFor(tester, find.byType(TextField));
    await tester.enterText(
      find.byType(TextField).last,
      'Hello from the emulator',
    );
    await tester.pump();
    await _tap(tester, find.byTooltip('Send message'));
    // The composer clears once the message is sent, so this matches the
    // message in the list, not the draft.
    await _waitFor(
      tester,
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Hello from the emulator'),
      ),
    );

    // A link is held for moderation, and the sender is told.
    await tester.pump(const Duration(milliseconds: 1500)); // rate limit
    await tester.enterText(
      find.byType(TextField).last,
      'Official info at www.daad.de',
    );
    await tester.pump();
    await _tap(tester, find.byTooltip('Send message'));
    await _waitFor(
      tester,
      find.textContaining('Waiting for moderator approval'),
    );
  });

  testWidgets('the student deletes the account; sign-in is then refused', (
    tester,
  ) async {
    await _startApp(tester);
    // The previous test left the student signed in.
    await _waitFor(tester, find.byType(NavigationBar));
    await _tap(tester, find.byIcon(Icons.person_outline));
    await _tap(tester, find.text('Delete account'));
    await _type(tester, 'Type DELETE to confirm', 'DELETE');
    await _type(tester, 'Your password', _password);
    await _tap(tester, find.widgetWithText(FilledButton, 'Delete account'));
    try {
      await _waitFor(
        tester,
        find.text('Your path to studying in Germany'),
        timeout: const Duration(seconds: 60),
      );
    } on TestFailure {
      // Diagnose: call the function directly and print what goes wrong.
      try {
        await _services.authRepository.reauthenticate(password: _password);
        await FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: functionsRegion,
        ).httpsCallable('deleteMyAccount').call<Object?>();
        debugPrint('E2E-DIAG direct deleteMyAccount succeeded');
      } on FirebaseFunctionsException catch (error) {
        debugPrint(
          'E2E-DIAG deleteMyAccount: ${error.code} ${error.message} ${error.details}',
        );
      } catch (error) {
        debugPrint('E2E-DIAG deleteMyAccount failed: $error');
      }
      rethrow;
    }

    final user = await _lookupUser(_studentEmail);
    expect(user['disabled'], isTrue);
    final profile = await _rest(
      'GET',
      '$_firestore/users/${user['localId']}',
      admin: true,
    );
    expect((profile['fields'] as Map)['displayName'], {
      'stringValue': 'Deleted user',
    });

    // The disabled account cannot sign in again.
    await _signIn(tester, _studentEmail);
    await _waitFor(
      tester,
      find.text(
        'This account is disabled. Contact support if you think this is a mistake.',
      ),
    );

    // Neutral messages: a wrong password and a taken email reveal nothing.
    await _type(tester, 'Email', _ownerEmail);
    await _type(tester, 'Password', 'wrong-Passw0rd');
    await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await _waitFor(
      tester,
      find.text('That email and password do not match an account.'),
    );
  });
}
