// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
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
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // -----------------------
  // WEB（✅ 已填入真實值）
  // -----------------------
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAtipjUHy_aInMD_WNY0JL_RsMfv88fTQY',
    authDomain: 'global-hi-app.firebaseapp.com',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
    messagingSenderId: '569654002656',
    appId: '1:569654002656:web:93160142b0980e8313a185',
    measurementId: 'G-RQ6YSSYKFB',
  );

  // -----------------------
  // ANDROID
  // -----------------------
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbQVFqXoXlsxZ0H55NHVfYT9gYbTAxRS0',
    appId: '1:569654002656:android:3616f4261c8e527513a185',
    messagingSenderId: '569654002656',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
  );

  // -----------------------
  // iOS / macOS / Windows / Linux（如需才替換）
  // -----------------------
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_IOS_API_KEY',
    appId: 'REPLACE_IOS_APP_ID',
    messagingSenderId: 'REPLACE_IOS_SENDER_ID',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
    iosClientId: 'REPLACE_IOS_CLIENT_ID',
    iosBundleId: 'REPLACE_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_MACOS_API_KEY',
    appId: 'REPLACE_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_MACOS_SENDER_ID',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WINDOWS_API_KEY',
    appId: 'REPLACE_WINDOWS_APP_ID',
    messagingSenderId: 'REPLACE_WINDOWS_SENDER_ID',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_LINUX_API_KEY',
    appId: 'REPLACE_LINUX_APP_ID',
    messagingSenderId: 'REPLACE_LINUX_SENDER_ID',
    projectId: 'global-hi-app',
    storageBucket: 'global-hi-app.firebasestorage.app',
  );
}
