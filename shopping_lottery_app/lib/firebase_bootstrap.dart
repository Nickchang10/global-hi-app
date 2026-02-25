import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'firebase_web_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> ensureInitialized() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 避免 hot restart / 多處呼叫導致 duplicate-app
    if (Firebase.apps.isNotEmpty) return;

    if (kIsWeb) {
      await Firebase.initializeApp(options: firebaseWebOptions);

      // ✅ Web 端穩定化：關閉 persistence，避免 IndexedDB 狀態造成 firebase-js-sdk 內部崩潰
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    } else {
      await Firebase.initializeApp();
    }
  }
}
