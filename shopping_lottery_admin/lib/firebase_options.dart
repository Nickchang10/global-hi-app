import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

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
        return web; // ✅ 更安全
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
    iosClientId:
        '569654002656-a43cdjeit5ch9parl4c4hil4hbk875vd.apps.googleusercontent.com',
    iosBundleId: 'com.example.shoppingLotteryAdmin',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBdUk1d6i1XPKxQHB2ak0BviIUmejLZC2Y',
    appId: '1:569654002656:ios:c2875faaabb849a313a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
    iosClientId:
        '569654002656-a43cdjeit5ch9parl4c4hil4hbk875vd.apps.googleusercontent.com',
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

  static const FirebaseOptions linux = web; // ✅ 不要 REPLACE_ME
}
