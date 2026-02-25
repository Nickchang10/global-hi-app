import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ✅ 舊頁面相容 getter
  String? get email => _auth.currentUser?.email;
  String? get uid => _auth.currentUser?.uid;
  String? get displayName => _auth.currentUser?.displayName;
  String? get photoUrl => _auth.currentUser?.photoURL;
  bool get isSignedIn => _auth.currentUser != null;

  // =========================
  // Web 記住登入狀態
  // =========================
  Future<void> ensureWebPersistence() async {
    if (!kIsWeb) return;
    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } catch (_) {
      // ignore
    }
  }

  // =========================
  // ✅ Email/Password 登入（不再使用 deprecated fetchSignInMethodsForEmail）
  // =========================
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final e = email.trim();

    final cred = await _auth.signInWithEmailAndPassword(
      email: e,
      password: password,
    );

    await ensureUserDoc(cred.user);
    return cred;
  }

  // =========================
  // Email/Password 註冊
  // =========================
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    String role = 'user',
  }) async {
    final e = email.trim();

    final cred = await _auth.createUserWithEmailAndPassword(
      email: e,
      password: password,
    );

    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(displayName.trim());
    }

    await ensureUserDoc(cred.user, role: role);
    return cred;
  }

  // 忘記密碼
  Future<void> sendPasswordReset(String email) async {
    final e = email.trim();
    await _auth.sendPasswordResetEmail(email: e);
  }

  // 登出
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // =========================
  // ✅ 舊程式相容方法
  // =========================
  Future<UserCredential> login(String email, String password) {
    return signInWithEmail(email: email, password: password);
  }

  Future<UserCredential> register(
    String email,
    String password, {
    String? displayName,
  }) {
    return registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      role: 'user',
    );
  }

  Future<void> logout() => signOut();

  Future<void> resetPassword(String email) => sendPasswordReset(email);

  // =========================
  // users/{uid} 文件維護（配合你的 rules）
  // =========================
  Future<void> ensureUserDoc(User? user, {String role = 'user'}) async {
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'role': role, // 你的 rules: create 時必須 role=="user"
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    } else {
      await ref.set({
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }
  }

  // 讀取角色
  Future<String> getRole() async {
    final u = currentUser;
    if (u == null) return 'guest';

    final snap = await _db.collection('users').doc(u.uid).get();
    if (!snap.exists) return 'user';

    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final role = data['role'];
    if (role is String && role.isNotEmpty) return role;
    return 'user';
  }

  // 錯誤訊息轉中文
  static String formatAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Email 格式不正確';
        case 'user-not-found':
          return '此 Email 尚未註冊（找不到帳號）';
        case 'wrong-password':
        case 'invalid-credential':
          return '帳號或密碼錯誤';
        case 'email-already-in-use':
          return '此 Email 已被註冊';
        case 'weak-password':
          return '密碼強度不足（請至少 6 碼以上）';
        case 'operation-not-allowed':
          return 'Firebase 尚未啟用 Email/Password 登入（Console → Auth → Sign-in method）';
        case 'too-many-requests':
          return '嘗試次數過多，請稍後再試';
        case 'network-request-failed':
          return '網路連線失敗，請檢查網路/代理設定';
        default:
          return '登入失敗：${e.code}${e.message != null ? '｜${e.message}' : ''}';
      }
    }
    return '發生錯誤：$e';
  }
}
