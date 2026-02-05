// lib/controllers/admin_mode_controller.dart
//
// ✅ AdminModeController v10.0 Final（完全整合版）
// ------------------------------------------------------------
// 特色：
// - 相容新舊呼叫方式（isFullMode / toggleMode）
// - 保留 main.dart 依賴的 clearPersisted / setRole / ensureLoaded / isSimpleMode
// - 安全通知機制 _safeNotifyListeners()
// - 可 await 的 toggle()
// - 移除 Switcher widget，請獨立於 widgets/admin_mode_switcher.dart
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 後台顯示模式
enum AdminMode { simple, full }

/// ✅ Provider 控制器
class AdminModeController extends ChangeNotifier {
  AdminMode _mode = AdminMode.full;
  String _role = '';
  bool _loaded = false;

  // ----------------------------
  // Getters
  // ----------------------------
  AdminMode get mode => _mode;

  bool get isSimple => _mode == AdminMode.simple;
  bool get isFull => _mode == AdminMode.full;

  /// main.dart 舊版本依賴
  bool get isSimpleMode => isSimple;

  /// admin_shell_page 舊版依賴
  bool get isFullMode => isFull;

  String get role => _role;
  bool get isAdmin => _role.toLowerCase() == 'admin';
  bool get isVendor => _role.toLowerCase() == 'vendor';

  bool get isLoaded => _loaded;

  // ----------------------------
  // Safe notify（避免 build 階段衝突）
  // ----------------------------
  void _safeNotifyListeners() {
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!hasListeners) return;
        notifyListeners();
      });
    }
  }

  // ----------------------------
  // 模式控制
  // ----------------------------
  void setMode(AdminMode m) {
    if (_mode == m) return;
    _mode = m;
    _safeNotifyListeners();
  }

  void setSimpleMode(bool simple) {
    final next = simple ? AdminMode.simple : AdminMode.full;
    if (_mode == next) return;
    _mode = next;
    _safeNotifyListeners();
  }

  void setFullMode() => setMode(AdminMode.full);
  void setSimple() => setMode(AdminMode.simple);

  /// ✅ 支援 await 的 toggle()
  Future<void> toggle() async {
    _mode = isSimple ? AdminMode.full : AdminMode.simple;
    _safeNotifyListeners();
  }

  /// ✅ 舊呼叫相容：AdminShellPage 用
  void toggleMode() {
    _mode = isSimple ? AdminMode.full : AdminMode.simple;
    _safeNotifyListeners();
  }

  // ----------------------------
  // 角色控制
  // ----------------------------
  void setRole(String role) {
    final next = role.trim();
    if (_role == next) return;
    _role = next;

    // 若廠商預設簡潔模式可啟用以下設定：
    // if (isVendor && isFull) {
    //   _mode = AdminMode.simple;
    // }

    _safeNotifyListeners();
  }

  // ----------------------------
  // 初始化
  // ----------------------------
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    _safeNotifyListeners();
  }

  // ----------------------------
  // 清除
  // ----------------------------
  void clearPersisted() {
    _role = '';
    _mode = AdminMode.full;
    _loaded = false;
    _safeNotifyListeners();
  }
}
