// lib/firebase_bootstrap.dart
import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> ensureInitialized() async {
    dev.log('FirebaseBootstrap.ensureInitialized() start', name: 'FB');

    WidgetsFlutterBinding.ensureInitialized();

    dev.log('Firebase.apps.length(before)=${Firebase.apps.length}', name: 'FB');

    if (Firebase.apps.isNotEmpty) {
      dev.log('Firebase already initialized, skip', name: 'FB');
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    dev.log(
      'Firebase initialized OK. apps=${Firebase.apps.map((e) => e.name).toList()}',
      name: 'FB',
    );
  }
}
