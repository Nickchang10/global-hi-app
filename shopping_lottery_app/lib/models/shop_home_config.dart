// lib/models/shop_home_config.dart
//
// ✅ ShopHomeConfig（商城首頁設定 Model｜完整版｜可編譯）
// ------------------------------------------------------------
// Firestore: shop_config/home
// 建議結構：
// {
//   enabled: true,
//   updatedAt: Timestamp,
//   updatedBy: "uid"(optional),
//   sections: [
//     {
//       id: "sec_xxx",
//       type: "banner" | "products" | "categories" | "rich_text",
//       enabled: true,
//       title: "string",
//       subtitle: "string",
//       imageUrl: "https://...",
//       linkUrl: "https://...",
//       productIds: ["p1","p2"],
//       categoryIds: ["c1","c2"],
//       layout: "carousel" | "grid" | "list",
//       limit: 12,
//       body: "...."
//     }
//   ]
// }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class ShopHomeConfig {
  final bool enabled;
  final List<ShopHomeSection> sections;

  final DateTime? updatedAt;
  final String updatedBy;

  const ShopHomeConfig({
    required this.enabled,
    required this.sections,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory ShopHomeConfig.empty() => const ShopHomeConfig(
        enabled: true,
        sections: <ShopHomeSection>[],
        updatedAt: null,
        updatedBy: '',
      );

  /// doc.data() 的 Map 直接丟進來即可
  factory ShopHomeConfig.fromDoc(Map<String, dynamic> data) {
    final enabled = _asBool(data['enabled'], fallback: true);

    final rawList = data['sections'];
    final sections = <ShopHomeSection>[];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is Map) {
          sections.add(
            ShopHomeSection.fromMap(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    return ShopHomeConfig(
      enabled: enabled,
      sections: sections,
      updatedAt: _toDateTime(data['updatedAt']),
      updatedBy: (data['updatedBy'] ?? '').toString(),
    );
  }

  /// 只拿「總開關 enabled=true 且 區塊 enabled=true」的區塊
  List<ShopHomeSection> get enabledSections {
    if (!enabled) return const [];
    return sections.where((s) => s.enabled).toList(growable: false);
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'sections': sections.map((e) => e.toMap()).toList(),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (updatedBy.isNotEmpty) 'updatedBy': updatedBy,
    };
  }

  ShopHomeConfig copyWith({
    bool? enabled,
    List<ShopHomeSection>? sections,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return ShopHomeConfig(
      enabled: enabled ?? this.enabled,
      sections: sections ?? this.sections,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

@immutable
class ShopHomeSection {
  final String id;
  final String type; // banner/products/categories/rich_text
  final bool enabled;

  final String title;
  final String subtitle;

  // banner
  final String imageUrl;
  final String linkUrl;

  // products/categories
  final List<String> productIds;
  final List<String> categoryIds;
  final String layout; // carousel/grid/list
  final int limit;

  // rich_text
  final String body;

  const ShopHomeSection({
    required this.id,
    required this.type,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.linkUrl,
    required this.productIds,
    required this.categoryIds,
    required this.layout,
    required this.limit,
    required this.body,
  });

  factory ShopHomeSection.fromMap(Map<String, dynamic> m) {
    final type = (m['type'] ?? 'rich_text').toString().trim();
    return ShopHomeSection(
      id: (m['id'] ?? '').toString(),
      type: type,
      enabled: m['enabled'] == true,
      title: (m['title'] ?? '').toString(),
      subtitle: (m['subtitle'] ?? '').toString(),
      imageUrl: (m['imageUrl'] ?? '').toString(),
      linkUrl: (m['linkUrl'] ?? '').toString(),
      productIds: _asStringList(m['productIds']),
      categoryIds: _asStringList(m['categoryIds']),
      layout: (m['layout'] ?? 'carousel').toString(),
      limit: _asInt(m['limit'], fallback: 12),
      body: (m['body'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    final out = <String, dynamic>{
      'id': id,
      'type': type,
      'enabled': enabled,
      'title': title,
      'subtitle': subtitle,
      'layout': layout,
      'limit': limit,
    };

    if (type == 'banner') {
      out['imageUrl'] = imageUrl;
      out['linkUrl'] = linkUrl;
    }
    if (type == 'products') {
      out['productIds'] = productIds;
    }
    if (type == 'categories') {
      out['categoryIds'] = categoryIds;
    }
    if (type == 'rich_text') {
      out['body'] = body;
    }

    return out;
  }

  ShopHomeSection copyWith({
    String? id,
    String? type,
    bool? enabled,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? linkUrl,
    List<String>? productIds,
    List<String>? categoryIds,
    String? layout,
    int? limit,
    String? body,
  }) {
    return ShopHomeSection(
      id: id ?? this.id,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      productIds: productIds ?? this.productIds,
      categoryIds: categoryIds ?? this.categoryIds,
      layout: layout ?? this.layout,
      limit: limit ?? this.limit,
      body: body ?? this.body,
    );
  }
}

// ============================================================
// Utils
// ============================================================

bool _asBool(dynamic v, {required bool fallback}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

int _asInt(dynamic v, {required int fallback}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}
