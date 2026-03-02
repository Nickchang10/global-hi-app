// lib/firebase_bootstrap.dart
import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  // indicates whether initialization finished successfully
  static bool initialized = false;

  static Future<void> ensureInitialized() async {
    dev.log('FirebaseBootstrap.ensureInitialized() start', name: 'FB');

    // ensure binding (safe to call multiple times)
    WidgetsFlutterBinding.ensureInitialized();

    try {
      dev.log(
        'Firebase.apps.length(before)=${Firebase.apps.length}',
        name: 'FB',
      );

      if (Firebase.apps.isNotEmpty) {
        dev.log('Firebase already initialized, skip', name: 'FB');
        initialized = true;
        return;
      }

      // Try initialize with options (this may throw if config incorrect)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      initialized = true;
      dev.log(
        'Firebase initialized OK. apps=${Firebase.apps.map((e) => e.name).toList()}',
        name: 'FB',
      );
    } catch (e, st) {
      // IMPORTANT: do NOT rethrow — allow app to continue in non-Firebase env.
      initialized = false;
      dev.log(
        'Firebase initialize failed: $e',
        error: e,
        stackTrace: st,
        name: 'FB',
      );
      // If you want to surface an in-app warning, you can set a global flag or show a dialog later.
    }
  }
}
