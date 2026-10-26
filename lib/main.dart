import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'config/app_config.dart';
import 'config/firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

Future<void> _start() async {
  // Configuration errors are programming errors: fail loudly.
  final config = AppConfig.fromEnvironment();
  final firebase = FirebaseConfig.fromEnvironment(config);

  try {
    final services = await createServices(config, firebase);
    runApp(DeutschhelferApp(config: config, services: services));
  } on StateError {
    rethrow;
  } catch (_) {
    // Usually a network or platform failure during Firebase startup.
    runApp(const StartupErrorApp(onRetry: _start));
  }
}
