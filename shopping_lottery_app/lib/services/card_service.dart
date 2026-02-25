// lib/services/card_service.dart
//
// ✅ CardService（卡片管理｜最終可編譯版）
// ------------------------------------------------------------
// 修正重點：
// - ✅ curly_braces_in_flow_control_structures：for 迴圈內一律使用 { } block
//
// 功能：
// - 管理卡片列表（記憶體）
// - CRUD：新增 / 更新 / 刪除 / 清空
// - 提供查詢：byId、activeCards、totalBalance
//
// 可搭配 Provider 使用：ChangeNotifierProvider(create: (_) => CardService())
//
// 你如果之後要接 Firestore：把 loadFromFirestore / syncToFirestore 補上即可
// ------------------------------------------------------------

import 'package:flutter/foundation.dart';

class CardService extends ChangeNotifier {
  final List<CardModel> _cards = <CardModel>[];

  List<CardModel> get cards => List<CardModel>.unmodifiable(_cards);

  /// 只取啟用卡
  List<CardModel> get activeCards {
    final out = <CardModel>[];
    for (final c in _cards) {
      if (c.isActive) {
        out.add(c);
      }
    }
    return out;
  }

  /// 總餘額（僅計入啟用卡）
  num get totalBalance {
    num sum = 0;
    for (final c in _cards) {
      if (c.isActive) {
        sum += c.balance;
      }
    }
    return sum;
  }

  CardModel? byId(String id) {
    for (final c in _cards) {
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }

  /// 新增（若 id 重複就改成更新）
  void upsert(CardModel card) {
    final idx = _cards.indexWhere((c) => c.id == card.id);
    if (idx >= 0) {
      _cards[idx] = card;
    } else {
      _cards.add(card);
    }
    notifyListeners();
  }

  /// 只更新部分欄位（找不到就不做事）
  void updateFields(
    String id, {
    String? name,
    String? numberMasked,
    num? balance,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    final idx = _cards.indexWhere((c) => c.id == id);
    if (idx < 0) return;

    final old = _cards[idx];
    _cards[idx] = old.copyWith(
      name: name,
      numberMasked: numberMasked,
      balance: balance,
      isActive: isActive,
      updatedAt: updatedAt ?? DateTime.now(),
    );
    notifyListeners();
  }

  void remove(String id) {
    _cards.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void clear() {
    _cards.clear();
    notifyListeners();
  }

  /// Demo: 塞入示範卡片（避免空畫面）
  void seedDemo() {
    if (_cards.isNotEmpty) return;

    final now = DateTime.now();
    _cards.addAll([
      CardModel(
        id: 'card_1',
        name: '大哥大儲值卡',
        numberMasked: '**** **** **** 1234',
        balance: 200,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      CardModel(
        id: 'card_2',
        name: 'ED1000 服務卡',
        numberMasked: '**** **** **** 8888',
        balance: 0,
        isActive: false,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    notifyListeners();
  }
}

@immutable
class CardModel {
  const CardModel({
    required this.id,
    required this.name,
    required this.numberMasked,
    required this.balance,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String numberMasked;
  final num balance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CardModel copyWith({
    String? id,
    String? name,
    String? numberMasked,
    num? balance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      numberMasked: numberMasked ?? this.numberMasked,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'numberMasked': numberMasked,
      'balance': balance,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  static CardModel fromMap(Map<String, dynamic> map) {
    DateTime dt(dynamic v) {
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    num n(dynamic v) {
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '') ?? 0;
    }

    return CardModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '卡片').toString(),
      numberMasked: (map['numberMasked'] ?? '****').toString(),
      balance: n(map['balance']),
      isActive: (map['isActive'] ?? true) == true,
      createdAt: dt(map['createdAt']),
      updatedAt: dt(map['updatedAt']),
    );
  }
}
