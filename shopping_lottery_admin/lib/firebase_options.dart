// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// ⚠️ 佔位版：先讓專案能編譯/跑起來
/// 請把下面的 apiKey / appId / messagingSenderId / projectId…
/// 換成你 Firebase Console 的真實設定，或重新跑 flutterfire configure 產生正式檔案。
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAtipjUHy_aInMD_WNY0JL_RsMfv88fTQY',
    appId: '1:569654002656:web:60089c954fc5721913a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    authDomain: 'global-hi-app.firebaseapp.com',
    storageBucket: 'global-hi-app.firebasestorage.app',
    measurementId: 'G-BB1BHZHEJ6',
  );

  // ✅ 下面全部請換成真實值（先填佔位也能編譯，但 Firebase 可能無法連線）

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbQVFqXoXlsxZ0H55NHVfYT9gYbTAxRS0',
    appId: '1:569654002656:android:3616f4261c8e527513a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBdUk1d6i1XPKxQHB2ak0BviIUmejLZC2Y',
    appId: '1:569654002656:ios:c2875faaabb849a313a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
    iosClientId: '569654002656-a43cdjeit5ch9parl4c4hil4hbk875vd.apps.googleusercontent.com',
    iosBundleId: 'com.example.shoppingLotteryAdmin',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBdUk1d6i1XPKxQHB2ak0BviIUmejLZC2Y',
    appId: '1:569654002656:ios:c2875faaabb849a313a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
    iosClientId: '569654002656-a43cdjeit5ch9parl4c4hil4hbk875vd.apps.googleusercontent.com',
    iosBundleId: 'com.example.shoppingLotteryAdmin',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAtipjUHy_aInMD_WNY0JL_RsMfv88fTQY',
    appId: '1:569654002656:web:60089c954fc5721913a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    authDomain: 'global-hi-app.firebaseapp.com',
    storageBucket: 'global-hi-app.firebasestorage.app',
    measurementId: 'G-BB1BHZHEJ6',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
  );
}