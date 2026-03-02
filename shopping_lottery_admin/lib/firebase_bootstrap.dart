import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  // ✅ 保底：就算你專案裡還有其他舊檢查/舊 options，也能初始化起來
  static const FirebaseOptions _webFallback = FirebaseOptions(
    apiKey: 'AIzaSyAtipjUHy_aInMD_WNY0JL_RsMfv88fTQY',
    appId: '1:569654002656:web:60089c954fc5721913a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    authDomain: 'global-hi-app.firebaseapp.com',
    storageBucket: 'global-hi-app.firebasestorage.app',
    measurementId: 'G-BB1BHZHEJ6',
  );

  static bool _valid(FirebaseOptions o) {
    return o.apiKey.isNotEmpty &&
        o.appId.isNotEmpty &&
        o.projectId.isNotEmpty &&
        o.messagingSenderId.isNotEmpty;
  }

  static Future<void> ensureInitialized() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 避免 hot-reload / 多次 init
    if (Firebase.apps.isNotEmpty) return;

    FirebaseOptions options;

    if (kIsWeb) {
      // ✅ 優先用 flutterfire 產生的 web；若被舊檔案/佔位值污染，改用 fallback
      final webOpt = DefaultFirebaseOptions.web;
      options = _valid(webOpt) ? webOpt : _webFallback;
    } else {
      // 非 web：用 currentPlatform
      options = DefaultFirebaseOptions.currentPlatform;
      // 若你某平台 options 仍是 REPLACE_ME，也做保底（不影響 web）
      if (!_valid(options) && kDebugMode) {
        // ignore: avoid_print
        print(
          '[FirebaseBootstrap] WARNING: FirebaseOptions seems invalid on this platform.',
        );
      }
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[FirebaseBootstrap] init projectId=${options.projectId} appId=${options.appId}',
      );
    }

    await Firebase.initializeApp(options: options);
  }
}
