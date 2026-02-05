// lib/firebase_options.dart
// ======================================================
// ✅ Firebase Options（Web / Android / iOS）完整版模板
// 用法：await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// ======================================================
//
// ⚠️ 注意：這份檔案的值（apiKey / appId / projectId...）必須換成你自己的 Firebase 專案設定。
// 取得方式：
// 1) 安裝並登入 FlutterFire CLI
//    dart pub global activate flutterfire_cli
//    flutterfire configure
// 2) 它會自動產生正確的 firebase_options.dart（建議以它為準）
//
// 如果你要先「可編譯」跑起來：請把下方所有 YOUR_* 全部改成你 Firebase Console 的實際值。

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // =========================
  // ✅ Web

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAtipjUHy_aInMD_WNY0JL_RsMfv88fTQY',
    appId: '1:569654002656:web:93160142b0980e8313a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    authDomain: 'global-hi-app.firebaseapp.com',
    storageBucket: 'global-hi-app.firebasestorage.app',
    measurementId: 'G-RQ6YSSYKFB',
  );

  // =========================

  // =========================
  // ✅ Android

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbQVFqXoXlsxZ0H55NHVfYT9gYbTAxRS0',
    appId: '1:569654002656:android:9d5b8a6d92b6f27013a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
  );

  // =========================

  // =========================
  // ✅ iOS

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBdUk1d6i1XPKxQHB2ak0BviIUmejLZC2Y',
    appId: '1:569654002656:ios:7c30cbd78b97c47c13a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
    iosClientId: '569654002656-jtpat6d1gcm9apv3q3iirkqlevu3c9g6.apps.googleusercontent.com',
    iosBundleId: 'com.example.shoppingLotteryApp',
  );

  // =========================

  // =========================
  // ✅ macOS（若你不做 macOS 可先留著，或直接不使用）

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBdUk1d6i1XPKxQHB2ak0BviIUmejLZC2Y',
    appId: '1:569654002656:ios:7c30cbd78b97c47c13a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
    iosClientId: '569654002656-jtpat6d1gcm9apv3q3iirkqlevu3c9g6.apps.googleusercontent.com',
    iosBundleId: 'com.example.shoppingLotteryApp',
  );

  // =========================

  // =========================
  // ✅ Windows / Linux（通常可不填；若用到再補）

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAtipjUHy_aInMD_WNY0JL_RsMfv88fTQY',
    appId: '1:569654002656:web:e5b0130495308e8013a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    authDomain: 'global-hi-app.firebaseapp.com',
    storageBucket: 'global-hi-app.firebasestorage.app',
    measurementId: 'G-M7WFS5ZSND',
  );

  // =========================

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_LINUX_API_KEY',
    appId: 'YOUR_LINUX_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}