/* lib/services/security_service.dart */

import 'dart:collection';

class SecurityService {
  SecurityService._internal();
  static final SecurityService instance = SecurityService._internal();

  /// 防火牆是否啟用
  bool _firewallEnabled = false;

  /// 黑名單（封鎖的帳號）
  final List<String> _blacklist = [];

  /// 安全日誌
  final List<String> _logs = [];

  // ------------------ Getter ------------------
  bool get firewallEnabled => _firewallEnabled;

  List<String> get blacklist => UnmodifiableListView(_blacklist);

  List<String> get logs => UnmodifiableListView(_logs);

  // ------------------ Actions ------------------

  /// 切換防火牆狀態
  void toggleFirewall(bool enabled) {
    _firewallEnabled = enabled;
    _logs.add("防火牆狀態變更：${enabled ? "開啟" : "關閉"}");
  }

  /// 封鎖使用者
  void blockUser(String username) {
    if (!_blacklist.contains(username)) {
      _blacklist.add(username);
      _logs.add("封鎖使用者：$username");
    }
  }

  /// 模擬遭受攻擊（示範用）
  void simulateAttackAttempt(String source) {
    _logs.add("偵測到可疑行為：$source");
  }
}
