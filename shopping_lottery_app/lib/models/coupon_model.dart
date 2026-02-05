// lib/models/coupon_model.dart

/// 優惠券資料模型
///
/// 基本欄位：
/// - [code]       優惠碼（唯一）
/// - [name]       顯示名稱（例如：新會員折 100）
/// - [expireDate] 到期日
/// - [used]       是否已使用
///
/// 延伸欄位（可選）：
/// - [description]   說明文字（列表 / 詳情頁顯示）
/// - [issueDate]     發放日期（預設為 now）
/// - [amountOff]     固定金額折抵（例：100）
/// - [percentOff]    百分比折抵（0~1，例如 0.2 = 8 折）
/// - [minSpend]      最低消費門檻（例：滿 1000 可用）
/// - [freeShipping]  是否免運券
/// - [memberOnly]    是否限定會員使用
/// - [memberPlan]    限定會員等級（例：Premium / Pro）
/// - [stackable]     是否可與其他優惠併用
class CouponModel {
  final String code;
  final String name;
  final DateTime expireDate;

  /// 優惠券說明（例如：限智慧手錶使用）
  final String? description;

  /// 發放日期（預設為建立當下時間）
  final DateTime issueDate;

  /// 固定金額折抵（例如：100 元），與 [percentOff] 通常二擇一
  final int? amountOff;

  /// 折扣比例（0 ~ 1，例如 0.2 表示 8 折），與 [amountOff] 通常二擇一
  final double? percentOff;

  /// 最低消費金額（購物車總額需 >= minSpend 才能套用）
  final int? minSpend;

  /// 是否免運券（若為 true，UI 可以顯示「免運」標籤）
  final bool freeShipping;

  /// 是否限定會員使用（例如登入會員才可使用）
  final bool memberOnly;

  /// 限定會員方案（例：'Premium' / 'Pro'），僅在 [memberOnly] = true 時有意義
  final String? memberPlan;

  /// 是否可與其他優惠併用
  final bool stackable;

  /// 是否已使用
  bool used;

  CouponModel({
    required this.code,
    required this.name,
    required this.expireDate,
    this.description,
    DateTime? issueDate,
    this.amountOff,
    this.percentOff,
    this.minSpend,
    this.freeShipping = false,
    this.memberOnly = false,
    this.memberPlan,
    this.stackable = false,
    this.used = false,
  })  : issueDate = issueDate ?? DateTime.now(),
        assert(
          amountOff == null || amountOff >= 0,
          'amountOff 不能為負數',
        ),
        assert(
          percentOff == null || (percentOff > 0 && percentOff <= 1),
          'percentOff 必須介於 0(不含) ~ 1(含) 之間，例：0.2 = 8 折',
        );

  /// 是否已過期
  bool get isExpired => DateTime.now().isAfter(expireDate);

  /// 是否快到期（預設 3 天內）
  bool get isExpiringSoon {
    final now = DateTime.now();
    if (isExpired) return false;
    return expireDate.isBefore(now.add(const Duration(days: 3)));
  }

  /// 剩餘天數（已過期則回傳 0）
  int get remainingDays {
    final now = DateTime.now();
    if (isExpired) return 0;
    return expireDate.difference(now).inDays;
  }

  /// 是否為「金額折抵」型優惠券
  bool get isAmountCoupon => amountOff != null;

  /// 是否為「折扣比例」型優惠券
  bool get isPercentCoupon => percentOff != null;

  /// 是否可使用（未使用 + 未過期）
  bool get isAvailable => !used && !isExpired;

  /// 計算在給定購物車總金額下，此張優惠券可以折多少
  ///
  /// - 若不符合條件（已使用 / 過期 / 未達門檻），回傳 0
  /// - 百分比與固定金額皆為 null 時，也回傳 0
  /// - 折扣金額不會超過 cartTotal（避免變成負數）
  int calcDiscount(int cartTotal) {
    if (cartTotal <= 0) return 0;
    if (used || isExpired) return 0;

    // 檢查最低門檻
    if (minSpend != null && cartTotal < minSpend!) {
      return 0;
    }

    int discount = 0;

    if (percentOff != null) {
      discount = (cartTotal * percentOff!).floor();
    } else if (amountOff != null) {
      discount = amountOff!;
    }

    if (discount < 0) discount = 0;
    if (discount > cartTotal) discount = cartTotal;

    return discount;
  }

  /// 將此優惠券標記為已使用（若有需要在 Provider / Service 裡呼叫）
  void markUsed() {
    used = true;
  }

  /// 產生一個新的實例（用於狀態管理不可變更新）
  CouponModel copyWith({
    String? code,
    String? name,
    DateTime? expireDate,
    String? description,
    DateTime? issueDate,
    int? amountOff,
    double? percentOff,
    int? minSpend,
    bool? freeShipping,
    bool? memberOnly,
    String? memberPlan,
    bool? stackable,
    bool? used,
  }) {
    return CouponModel(
      code: code ?? this.code,
      name: name ?? this.name,
      expireDate: expireDate ?? this.expireDate,
      description: description ?? this.description,
      issueDate: issueDate ?? this.issueDate,
      amountOff: amountOff ?? this.amountOff,
      percentOff: percentOff ?? this.percentOff,
      minSpend: minSpend ?? this.minSpend,
      freeShipping: freeShipping ?? this.freeShipping,
      memberOnly: memberOnly ?? this.memberOnly,
      memberPlan: memberPlan ?? this.memberPlan,
      stackable: stackable ?? this.stackable,
      used: used ?? this.used,
    );
  }

  /// 方便做本地儲存 / 傳 API
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'description': description,
      'issueDate': issueDate.toIso8601String(),
      'expireDate': expireDate.toIso8601String(),
      'amountOff': amountOff,
      'percentOff': percentOff,
      'minSpend': minSpend,
      'freeShipping': freeShipping,
      'memberOnly': memberOnly,
      'memberPlan': memberPlan,
      'stackable': stackable,
      'used': used,
    };
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      issueDate: json['issueDate'] != null
          ? DateTime.parse(json['issueDate'] as String)
          : null,
      expireDate: DateTime.parse(json['expireDate'] as String),
      amountOff: json['amountOff'] as int?,
      percentOff: (json['percentOff'] as num?)?.toDouble(),
      minSpend: json['minSpend'] as int?,
      freeShipping: json['freeShipping'] as bool? ?? false,
      memberOnly: json['memberOnly'] as bool? ?? false,
      memberPlan: json['memberPlan'] as String?,
      stackable: json['stackable'] as bool? ?? false,
      used: json['used'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'CouponModel(code: $code, name: $name, used: $used, '
        'expireDate: $expireDate, amountOff: $amountOff, percentOff: $percentOff)';
  }
}
