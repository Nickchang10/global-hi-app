// lib/models/app_center_config.dart
//
// ✅ AppCenterConfig（前台/後台共用）
// - 讀取 Firestore: app_config/app_center
// - 文件不存在 / 欄位缺漏 -> defaults 防呆
//

class AppCenterConfig {
  final bool shopHomeEnabled;
  final bool bannerEnabled;
  final bool bottomNavEnabled;
  final bool featureToggleEnabled;
  final bool sosHealthEnabled;
  final bool deviceMgmtEnabled;

  const AppCenterConfig({
    required this.shopHomeEnabled,
    required this.bannerEnabled,
    required this.bottomNavEnabled,
    required this.featureToggleEnabled,
    required this.sosHealthEnabled,
    required this.deviceMgmtEnabled,
  });

  /// ✅ 統一用「方法」避免你現在 defaults 被推成 Function 的狀況
  static AppCenterConfig defaults() {
    return const AppCenterConfig(
      shopHomeEnabled: true,
      bannerEnabled: true,
      bottomNavEnabled: true,
      featureToggleEnabled: true,
      sosHealthEnabled: true,
      deviceMgmtEnabled: true,
    );
  }

  /// ✅ fromMap 允許傳入 null（直接回 defaults）
  factory AppCenterConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return AppCenterConfig.defaults();

    bool b(String key, {required bool fallback}) {
      final v = m[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true' || s == '1') return true;
        if (s == 'false' || s == '0') return false;
      }
      return fallback;
    }

    return AppCenterConfig(
      shopHomeEnabled: b('shopHomeEnabled', fallback: true),
      bannerEnabled: b('bannerEnabled', fallback: true),
      bottomNavEnabled: b('bottomNavEnabled', fallback: true),
      featureToggleEnabled: b('featureToggleEnabled', fallback: true),
      sosHealthEnabled: b('sosHealthEnabled', fallback: true),
      deviceMgmtEnabled: b('deviceMgmtEnabled', fallback: true),
    );
  }

  Map<String, dynamic> toMap() => {
        'shopHomeEnabled': shopHomeEnabled,
        'bannerEnabled': bannerEnabled,
        'bottomNavEnabled': bottomNavEnabled,
        'featureToggleEnabled': featureToggleEnabled,
        'sosHealthEnabled': sosHealthEnabled,
        'deviceMgmtEnabled': deviceMgmtEnabled,
      };

  AppCenterConfig copyWith({
    bool? shopHomeEnabled,
    bool? bannerEnabled,
    bool? bottomNavEnabled,
    bool? featureToggleEnabled,
    bool? sosHealthEnabled,
    bool? deviceMgmtEnabled,
  }) {
    return AppCenterConfig(
      shopHomeEnabled: shopHomeEnabled ?? this.shopHomeEnabled,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      bottomNavEnabled: bottomNavEnabled ?? this.bottomNavEnabled,
      featureToggleEnabled: featureToggleEnabled ?? this.featureToggleEnabled,
      sosHealthEnabled: sosHealthEnabled ?? this.sosHealthEnabled,
      deviceMgmtEnabled: deviceMgmtEnabled ?? this.deviceMgmtEnabled,
    );
  }
}
