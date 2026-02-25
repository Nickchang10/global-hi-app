// lib/services/app_state.dart
//
// ✅ AppState（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// 修正：所有 directives（import/export/part）都必須在任何宣告（class/var/function）之前
// ----------------------------------------------------
// 功能：
// - 監聽登入狀態（FirebaseAuth.userChanges）
// - 讀取 users/{uid} 使用者文件（role、points、displayName 等）
// - adminMode（可用於前後台切換、AdminGate）
// - SharedPreferences：記住 adminMode、localeCode
//
// 需要套件：firebase_auth, cloud_firestore, shared_preferences, flutter foundation
// ----------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// users collection
const String kUsersCollection = 'users';

/// 使用者文件常用欄位（你後台/資料若不同可在此統一調整）
class UserFields {
  static const String uid = 'uid';
  static const String email = 'email';
  static const String displayName = 'displayName';
  static const String photoUrl = 'photoUrl';

  static const String role = 'role'; // user / admin / super_admin / vendor ...
  static const String points = 'points';

  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
}

/// SharedPreferences keys
class AppPrefsKeys {
  static const String adminMode = 'adminModeEnabled';
  static const String localeCode = 'localeCode';
}

@immutable
class AppUserProfile {
  final String uid;
  final String? email;
  final String displayName;
  final String? photoUrl;
  final String role;
  final int points;

  final Map<String, dynamic> raw;

  const AppUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.role,
    required this.points,
    required this.raw,
  });

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory AppUserProfile.fromDoc(String uid, Map<String, dynamic> data) {
    return AppUserProfile(
      uid: uid,
      email: data[UserFields.email]?.toString(),
      displayName: (data[UserFields.displayName] ?? 'Osmile 會員').toString(),
      photoUrl: data[UserFields.photoUrl]?.toString(),
      role: (data[UserFields.role] ?? 'user').toString(),
      points: _toInt(data[UserFields.points]),
      raw: Map<String, dynamic>.from(data),
    );
  }
}

class AppState extends ChangeNotifier {
  AppState({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  bool _bootstrapped = false;
  bool _loading = false;
  String? _error;

  User? _firebaseUser;
  AppUserProfile? _profile;

  bool _adminModeEnabled = false;
  String? _localeCode;

  // ---------------- Getters ----------------

  bool get bootstrapped => _bootstrapped;
  bool get loading => _loading;
  String? get error => _error;

  User? get firebaseUser => _firebaseUser;
  AppUserProfile? get profile => _profile;

  String? get uid => _firebaseUser?.uid;
  bool get isLoggedIn => _firebaseUser != null;

  bool get adminModeEnabled => _adminModeEnabled;
  String? get localeCode => _localeCode;

  String get role => _profile?.role ?? 'user';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';
  int get points => _profile?.points ?? 0;

  // ---------------- Bootstrap ----------------

  /// ✅ 建議在 main() Provider 建立後呼叫一次：
  /// context.read<AppState>().bootstrap();
  Future<void> bootstrap() async {
    if (_bootstrapped) return;

    _setLoading(true);
    _error = null;

    try {
      _prefs = await SharedPreferences.getInstance();
      _adminModeEnabled = _prefs?.getBool(AppPrefsKeys.adminMode) ?? false;
      _localeCode = _prefs?.getString(AppPrefsKeys.localeCode);

      // 先抓目前 user（避免等第一個 stream event）
      _firebaseUser = _auth.currentUser;

      // 監聽登入狀態變化
      _authSub?.cancel();
      _authSub = _auth.userChanges().listen((u) {
        _firebaseUser = u;
        _error = null;

        // 登出：清掉 profile 並取消 profile 監聽
        if (u == null) {
          _profile = null;
          _cancelProfileSub();
          notifyListeners();
          return;
        }

        // 登入：確保 user doc 存在並開始監聽 profile
        _ensureUserDoc(u).then((_) {
          _startProfileListener(u.uid);
        });
        notifyListeners();
      });

      // 若一開始就已登入，直接監聽 profile
      if (_firebaseUser != null) {
        await _ensureUserDoc(_firebaseUser!);
        _startProfileListener(_firebaseUser!.uid);
      }

      _bootstrapped = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ---------------- Public Actions ----------------

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// ✅ 開關 adminMode（你可用來切換顯示後台入口）
  Future<void> setAdminModeEnabled(bool enabled) async {
    _adminModeEnabled = enabled;
    notifyListeners();
    try {
      await _prefs?.setBool(AppPrefsKeys.adminMode, enabled);
    } catch (_) {}
  }

  /// ✅ 設定語系（如果你有 i18n）
  Future<void> setLocaleCode(String? code) async {
    _localeCode = code;
    notifyListeners();
    try {
      if (code == null || code.trim().isEmpty) {
        await _prefs?.remove(AppPrefsKeys.localeCode);
      } else {
        await _prefs?.setString(AppPrefsKeys.localeCode, code.trim());
      }
    } catch (_) {}
  }

  /// ✅ 強制重新拉一次 profile（不靠 stream）
  Future<void> refreshProfileOnce() async {
    final u = _firebaseUser;
    if (u == null) return;

    _setLoading(true);
    _error = null;

    try {
      final snap = await _db.collection(kUsersCollection).doc(u.uid).get();
      final data = snap.data();
      if (data != null) {
        _profile = AppUserProfile.fromDoc(u.uid, data);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ---------------- Internals ----------------

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> _ensureUserDoc(User u) async {
    final ref = _db.collection(kUsersCollection).doc(u.uid);
    final snap = await ref.get();
    if (snap.exists) return;

    final now = FieldValue.serverTimestamp();
    await ref.set({
      UserFields.uid: u.uid,
      UserFields.email: u.email,
      UserFields.displayName: u.displayName ?? 'Osmile 會員',
      UserFields.photoUrl: u.photoURL,
      UserFields.role: 'user',
      UserFields.points: 0,
      UserFields.createdAt: now,
      UserFields.updatedAt: now,
    }, SetOptions(merge: true));
  }

  void _startProfileListener(String uid) {
    _cancelProfileSub();
    _profileSub = _db
        .collection(kUsersCollection)
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            final data = snap.data();
            if (data == null) {
              _profile = null;
            } else {
              _profile = AppUserProfile.fromDoc(uid, data);
            }
            _error = null;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  void _cancelProfileSub() {
    _profileSub?.cancel();
    _profileSub = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelProfileSub();
    super.dispose();
  }
}
