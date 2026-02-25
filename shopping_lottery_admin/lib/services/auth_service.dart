// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// ✅ 註冊（RegisterPage 需要：email + password + displayName）
  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // 設定 displayName（若有填）
    final name = (displayName ?? '').trim();
    if (name.isNotEmpty) {
      await cred.user?.updateDisplayName(name);
      await cred.user?.reload();
    }

    // ✅ 通知 UI（若你有 watch<AuthService>()）
    notifyListeners();
    return cred;
  }

  /// ✅ 登入（原本就有）
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // ✅ 通知 UI
    notifyListeners();
    return cred;
  }

  /// ✅ 別名：為了相容 main_admin.dart 的呼叫
  /// main_admin.dart 目前呼叫 signInWithEmailAndPassword(email:, password:)
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return signIn(email: email, password: password);
  }

  /// ✅ 登出
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  /// ✅ 寄送 Email 驗證信（RegisterPage 需要）
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 已驗證就不重送
    if (user.emailVerified) return;

    await user.sendEmailVerification();
  }

  /// ✅ 忘記密碼（可選）
  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// ✅ 更新顯示名稱（可選）
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final s = name.trim();
    if (s.isEmpty) return;
    await user.updateDisplayName(s);
    await user.reload();
    notifyListeners();
  }
}
