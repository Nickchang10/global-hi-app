// lib/services/campaign_rule_engine.dart
//
// ✅ Campaign Rule Engine（最終穩定版）
// ------------------------------------------------------------
// campaigns/{cid}.rules:
// - requirePaidOrder: bool
// - minPaidAmount: num
// - maxEntriesPerUser: int
// - allowMultipleWins: bool (抽獎是否允許同人多次中獎；預設 false)
// - note: String?（可選備註）
//
// 你可依需求擴充更多規則（例如指定商品、指定 vendor、指定等級會員等）
// ------------------------------------------------------------

import 'package:flutter/foundation.dart';

@immutable
class CampaignRules {
  final bool requirePaidOrder;
  final num minPaidAmount;
  final int maxEntriesPerUser;
  final bool allowMultipleWins;
  final String? note;

  const CampaignRules({
    this.requirePaidOrder = false,
    this.minPaidAmount = 0,
    this.maxEntriesPerUser = 1,
    this.allowMultipleWins = false,
    this.note,
  });

  factory CampaignRules.fromMap(Map<String, dynamic>? m) {
    final data = m ?? const <String, dynamic>{};
    num toNum(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);
    int toInt(dynamic v) => v is int ? v : (int.tryParse('$v') ?? 0);

    return CampaignRules(
      requirePaidOrder: data['requirePaidOrder'] == true,
      minPaidAmount: toNum(data['minPaidAmount']),
      maxEntriesPerUser: toInt(data['maxEntriesPerUser']).clamp(1, 999999),
      allowMultipleWins: data['allowMultipleWins'] == true,
      note: (data['note'] ?? '').toString().trim().isEmpty
          ? null
          : (data['note'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'requirePaidOrder': requirePaidOrder,
        'minPaidAmount': minPaidAmount,
        'maxEntriesPerUser': maxEntriesPerUser,
        'allowMultipleWins': allowMultipleWins,
        if (note != null) 'note': note,
      };

  CampaignRules copyWith({
    bool? requirePaidOrder,
    num? minPaidAmount,
    int? maxEntriesPerUser,
    bool? allowMultipleWins,
    String? note,
  }) {
    return CampaignRules(
      requirePaidOrder: requirePaidOrder ?? this.requirePaidOrder,
      minPaidAmount: minPaidAmount ?? this.minPaidAmount,
      maxEntriesPerUser: maxEntriesPerUser ?? this.maxEntriesPerUser,
      allowMultipleWins: allowMultipleWins ?? this.allowMultipleWins,
      note: note ?? this.note,
    );
  }
}

@immutable
class EligibilityResult {
  final bool eligible;
  final String message;

  const EligibilityResult(this.eligible, this.message);

  static const ok = EligibilityResult(true, '符合資格');
  static EligibilityResult fail(String msg) => EligibilityResult(false, msg);
}

class CampaignRuleEngine {
  /// ✅ 評估是否符合資格（由上層提供必要的事實：訂單數/已付款金額/已參加次數等）
  static EligibilityResult evaluate({
    required CampaignRules rules,
    required int paidOrdersCount,
    required num paidTotalAmount,
    required int existingEntriesCount,
    required bool isCampaignActive,
    required bool inTimeWindow,
  }) {
    if (!isCampaignActive) {
      return EligibilityResult.fail('活動未啟用');
    }
    if (!inTimeWindow) {
      return EligibilityResult.fail('不在活動期間');
    }

    if (existingEntriesCount >= rules.maxEntriesPerUser) {
      return EligibilityResult.fail('已達每人參加上限（${rules.maxEntriesPerUser} 次）');
    }

    if (rules.requirePaidOrder && paidOrdersCount <= 0) {
      return EligibilityResult.fail('需有至少一筆已付款訂單才可參加');
    }

    if (rules.minPaidAmount > 0 && paidTotalAmount < rules.minPaidAmount) {
      return EligibilityResult.fail('累計付款金額未達門檻（需 ≥ ${rules.minPaidAmount}）');
    }

    return EligibilityResult.ok;
  }
}
