// lib/services/auth_service.dart
// =====================================================
// ✅ Firebase AuthService（最終正式可編譯完整版）
// -----------------------------------------------------
// 支援：
// - Email 登入 / 註冊 / 自動登入 / 忘記密碼
// - 手機登入 / 註冊（驗證碼）
// - Firestore users/{uid} 同步
// - updateProfile 更新會員資料
// - 登出、監聽、單例呼叫（AuthService.instance）
// ✅ 重要修正：加入 factory AuthService() => instance
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 自訂登入錯誤例外（可選用，你的 UI 若 catch 這個會用到）
class AuthException implements Exception {
  final String code;
  final String message;
  AuthException(this.code, this.message);

  @override
  String toString() => 'AuthException($code): $message';
}

class AuthService extends ChangeNotifier {
  // =====================================================
  // Singleton 單例
  // =====================================================
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  /// ✅ 讓外部可直接呼叫 AuthService()，但實際回傳同一個 instance
  /// 這可解決你 login_page.dart: return AuthService(); 的編譯錯誤
  factory AuthService() => instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;
  Map<String, dynamic>? _userData;
  String? _verificationId;

  bool get initialized => _initialized;
  bool get loggedIn => _auth.currentUser != null;
  String get userId => _auth.currentUser?.uid ?? '';
  Map<String, dynamic>? get user => _userData;

  String get name => _userData?['name'] ?? 'Osmile 會員';
  String get phone => _userData?['phone'] ?? '09xx-xxx-xxx';
  String get level => _userData?['level'] ?? '一般會員';
  String? get email => _auth.currentUser?.email;
  String? get avatarUrl => _userData?['avatarUrl'];

  // =====================================================
  // 初始化監聽（自動同步 Firestore 資料）
  // =====================================================
  Future<void> init() async {
    if (_initialized) return;

    _auth.userChanges().listen((user) async {
      if (user == null) {
        _userData = null;
        notifyListeners();
        return;
      }

      try {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _userData = doc.data();
        } else {
          await _createUserDoc(user);
          _userData =
              (await _db.collection('users').doc(user.uid).get()).data();
        }
      } catch (e) {
        debugPrint('⚠️ 讀取使用者資料失敗：$e');
      }

      _initialized = true;
      notifyListeners();
    });

    _initialized = true;
    notifyListeners();
  }

  // =====================================================
  // Email 登入 / 註冊 / 忘記密碼
  // =====================================================

  /// ✅ Email 登入
  /// 回傳：null = 成功；非 null = 錯誤訊息
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _updateLoginTimestamp();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return '找不到此帳號';
        case 'wrong-password':
          return '密碼錯誤';
        case 'invalid-email':
          return 'Email 格式錯誤';
        default:
          return e.message ?? '登入失敗';
      }
    } catch (e) {
      debugPrint('⚠️ Email 登入失敗: $e');
      return '登入失敗';
    }
  }

  /// ✅ Email 註冊
  Future<String?> register(String name, String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _createUserDoc(cred.user!, name: name, email: email);
      await _updateLoginTimestamp();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return '此 Email 已被註冊';
        case 'invalid-email':
          return 'Email 格式錯誤';
        case 'weak-password':
          return '密碼強度太低，請至少 6 碼';
        default:
          return e.message ?? '註冊失敗';
      }
    } catch (e) {
      debugPrint('⚠️ 註冊失敗: $e');
      return '註冊失敗';
    }
  }

  /// ✅ Email 註冊 + 自動登入
  Future<String?> registerAndLogin(
      String name, String email, String password) async {
    final err = await register(name, email, password);
    if (err != null) return err;

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _updateLoginTimestamp();
      return null;
    } catch (e) {
      return '註冊成功但登入失敗，請手動登入';
    }
  }

  /// ✅ 發送重設密碼信件（具名參數版本）
  Future<String?> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // 成功
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return '找不到此帳號';
        case 'invalid-email':
          return 'Email 格式錯誤';
        default:
          return e.message ?? '寄送失敗';
      }
    } catch (e) {
      debugPrint('⚠️ 寄送重設密碼信件失敗：$e');
      return '寄送失敗';
    }
  }

  // =====================================================
  // 手機登入 / 註冊（驗證碼流程）
  // =====================================================
  Future<String?> loginWithPhone(String phone, {String? smsCode}) async {
    try {
      if (smsCode == null) {
        await _auth.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (cred) async {
            await _auth.signInWithCredential(cred);
            await _createUserIfNeeded(phone: phone);
            notifyListeners();
          },
          verificationFailed: (e) => debugPrint('⚠️ 驗證碼發送失敗：$e'),
          codeSent: (verId, _) => _verificationId = verId,
          codeAutoRetrievalTimeout: (verId) => _verificationId = verId,
        );
        return null;
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId ?? '',
          smsCode: smsCode,
        );
        await _auth.signInWithCredential(credential);
        await _createUserIfNeeded(phone: phone);
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ 手機登入失敗：$e');
      return '手機登入失敗';
    }
  }

  Future<String?> registerWithPhone({
    required String name,
    required String phone,
    String? smsCode,
  }) async {
    try {
      if (smsCode == null) {
        await _auth.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (cred) async {
            await _auth.signInWithCredential(cred);
            await _createUserIfNeeded(name: name, phone: phone);
          },
          verificationFailed: (e) => debugPrint('⚠️ 驗證碼發送失敗：$e'),
          codeSent: (verId, _) => _verificationId = verId,
          codeAutoRetrievalTimeout: (verId) => _verificationId = verId,
        );
        return null;
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId ?? '',
          smsCode: smsCode,
        );
        await _auth.signInWithCredential(credential);
        await _createUserIfNeeded(name: name, phone: phone);
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ 手機註冊失敗：$e');
      return '手機註冊失敗';
    }
  }

  // =====================================================
  // 登出
  // =====================================================
  Future<void> logout() async {
    await _auth.signOut();
    _userData = null;
    notifyListeners();
  }

  // =====================================================
  // 更新會員資料
  // =====================================================
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? level,
    String? avatarUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (level != null) 'level': level,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
    _userData = {...?_userData, ...data};
    notifyListeners();
  }

  // =====================================================
  // Firestore User 建立 / 更新
  // =====================================================
  Future<void> _createUserDoc(
    User user, {
    String? name,
    String? email,
    String? phone,
  }) async {
    final docRef = _db.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    await docRef.set({
      'id': user.uid,
      'name': name ?? 'Osmile 會員',
      'email': email ?? user.email,
      'phone': phone ?? '',
      'level': '一般會員',
      'role': 'user',
      'vendorId': '',
      'createdAt': now,
      'lastLoginAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> _createUserIfNeeded({String? name, String? phone}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _createUserDoc(user, name: name, phone: phone);
    }
  }

  Future<void> _updateLoginTimestamp() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'lastLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
