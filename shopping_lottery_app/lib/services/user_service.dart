import 'package:flutter/foundation.dart';

/// ✅ 全站共用的假會員資料（純前端模擬）
/// - 支援：登入 / 註冊 / 登出
/// - 支援：積分加減（給抽獎、下單用）
/// - 新增：userId 欄位（供訂單 / 紀錄關聯使用）
class UserService extends ChangeNotifier {
  // 單例
  static final UserService instance = UserService._internal();
  UserService._internal();

  // ---- 內部欄位 ----
  bool _isLoggedIn = false;

  // 🆔 唯一使用者 ID（模擬 UUID）
  String _id = "guest";

  String _name = "訪客";
  bool _isMember = false;
  int _points = 0;

  // 之後如果要顯示 email / phone 可以再加欄位
  String? _email;
  String? _phone;

  // ---- Getter ----
  bool get isLoggedIn => _isLoggedIn;
  String get id => _id;
  String get name => _name;
  bool get isMember => _isMember;
  int get points => _points;
  String? get email => _email;
  String? get phone => _phone;

  // ---- 基本設定 ----
  void setName(String name) {
    _name = name;
    notifyListeners();
  }

  void setMember(bool value) {
    _isMember = value;
    notifyListeners();
  }

  void setPoints(int value) {
    _points = value < 0 ? 0 : value;
    notifyListeners();
  }

  // ---- 積分操作（給抽獎 / 任務用）----
  void addPoints(int delta) {
    _points += delta;
    if (_points < 0) _points = 0;
    notifyListeners();
  }

  /// 扣點數；不夠點數會回傳 false
  bool consumePoints(int cost) {
    if (_points < cost) return false;
    _points -= cost;
    notifyListeners();
    return true;
  }

  // ---- 登入 / 註冊 / 登出（純前端模擬）----

  /// 一鍵 Demo 登入（例如展場快速登入）
  void loginDemo({String name = "展場訪客"}) {
    _isLoggedIn = true;
    _isMember = true;
    _name = name;
    _email = null;
    _phone = null;
    _id = "demo_${DateTime.now().millisecondsSinceEpoch}"; // ✅ 產生模擬 ID

    // 給一點示意積分
    if (_points == 0) {
      _points = 500;
    }
    notifyListeners();
  }

  /// 模擬「註冊並自動登入」
  void registerDemo({
    required String name,
    String? email,
    String? phone,
  }) {
    _isLoggedIn = true;
    _isMember = true;
    _name = name;
    _email = email;
    _phone = phone;
    _id = "user_${DateTime.now().millisecondsSinceEpoch}"; // ✅ 新使用者 ID
    _points = 300;
    notifyListeners();
  }

  /// 模擬登出：回到訪客狀態
  void logout() {
    _isLoggedIn = false;
    _isMember = false;
    _name = "訪客";
    _email = null;
    _phone = null;
    _points = 0;
    _id = "guest"; // ✅ 重設 ID
    notifyListeners();
  }
}
