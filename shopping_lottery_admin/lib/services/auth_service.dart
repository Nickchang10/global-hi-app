import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
// 若要啟用 Google 登入請解除下方註解並安裝套件：google_sign_in
// import 'package:google_sign_in/google_sign_in.dart';

/// 自訂例外：轉換 FirebaseAuthException 成中文訊息
class AuthException implements Exception {
  final String code;
  final String message;
  final Object? raw;
  AuthException(this.code, this.message, {this.raw});
  @override
  String toString() => 'AuthException($code): $message';
}

/// ✅ AuthService（最終完整版）
///
/// 功能：
/// - Email / 密碼註冊與登入（含 login 別名）
/// - 匿名登入
/// - 發送驗證信 / 重設密碼
/// - 查詢角色（super_admin / vendor_admin）
/// - 取得 vendorId（廠商 ID）
/// - 登出 / 刪除帳號 / 更新資料 / 重新驗證
/// - （選用）Google 登入
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ----------------------------------------------------
  // 使用者屬性與監聽
  // ----------------------------------------------------
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();
  Stream<User?> get userChanges => _auth.userChanges();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  // ----------------------------------------------------
  // Email 登入 / 註冊 / 匿名登入
  // ----------------------------------------------------
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _mapFirebaseError(e), raw: e);
    }
  }

  /// ✅ login() 為舊版兼容別名（供 login_page.dart 使用）
  Future<User?> login(String email, String password) async {
    return await signIn(email: email, password: password);
  }

  Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
    String role = 'user',
    String? vendorId,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'role': role,
          if (vendorId != null) 'vendorId': vendorId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _mapFirebaseError(e), raw: e);
    }
  }

  Future<User?> signInAnonymously() async {
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _mapFirebaseError(e), raw: e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  // ----------------------------------------------------
  // 角色與 Firestore 結構
  // ----------------------------------------------------
  Future<Map<String, dynamic>?> getUserRoleData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      throw AuthException('read_error', '無法讀取使用者資料：$e');
    }
  }

  Future<Map<String, dynamic>?> get currentUserRole async {
    final uid = currentUserId;
    if (uid == null) return null;
    return getUserRoleData(uid);
  }

  // ----------------------------------------------------
  // Email 驗證 / 密碼重設
  // ----------------------------------------------------
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('no_user', '尚未登入');
    await user.sendEmailVerification();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, _mapFirebaseError(e), raw: e);
    }
  }

  // ----------------------------------------------------
  // 更新個人資料
  // ----------------------------------------------------
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('no_user', '尚未登入');
    if (displayName != null) await user.updateDisplayName(displayName);
    if (photoURL != null) await user.updatePhotoURL(photoURL);
    await user.reload();
  }

  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('no_user', '尚未登入');
    await user.updateEmail(newEmail);
  }

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('no_user', '尚未登入');
    await user.updatePassword(newPassword);
  }

  // ----------------------------------------------------
  // Google 登入（選用）
  // ----------------------------------------------------
  Future<UserCredential?> signInWithGoogle() async {
    // 若要啟用請解除註解並安裝 google_sign_in 套件：
    //
    // final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    // if (googleUser == null) return null;
    // final googleAuth = await googleUser.authentication;
    // final credential = GoogleAuthProvider.credential(
    //   accessToken: googleAuth.accessToken,
    //   idToken: googleAuth.idToken,
    // );
    // final cred = await _auth.signInWithCredential(credential);
    // return cred;

    throw AuthException(
      'google_not_enabled',
      'Google 登入尚未啟用，請安裝 google_sign_in 並解除註解。',
    );
  }

  // ----------------------------------------------------
  // 刪除 / 重新驗證
  // ----------------------------------------------------
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('no_user', '尚未登入');

    final cred = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(cred);
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('no_user', '尚未登入');
    await user.delete();
  }

  // ----------------------------------------------------
  // Token / Reload
  // ----------------------------------------------------
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken(forceRefresh);
  }

  Future<void> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) await user.reload();
  }

  // ----------------------------------------------------
  // Utility：錯誤訊息轉換
  // ----------------------------------------------------
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '電子郵件格式不正確';
      case 'user-disabled':
        return '此帳號已被停用';
      case 'user-not-found':
        return '找不到此帳號';
      case 'wrong-password':
        return '密碼錯誤';
      case 'email-already-in-use':
        return '此 Email 已被使用';
      case 'weak-password':
        return '密碼強度不足';
      case 'requires-recent-login':
        return '需要重新登入才能執行此操作';
      case 'too-many-requests':
        return '請求過多，請稍後再試';
      case 'network-request-failed':
        return '網路連線失敗';
      default:
        return e.message ?? '發生未知錯誤';
    }
  }
}
