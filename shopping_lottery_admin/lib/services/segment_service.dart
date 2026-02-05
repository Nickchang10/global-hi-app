// lib/services/segment_service.dart
//
// ✅ SegmentService（受眾分群規則：儲存 schema + 遞迴評估 + Preview 取樣）
// ------------------------------------------------------------
// 規則節點（Map schema）
// - Group: { type:'group', op:'and'|'or', children:[node,...] }
// - Condition:
//   {
//     type:'condition',
//     field:'role' 或 'profile.age'（支援 dot path）,
//     valueType:'string'|'number'|'bool'|'date'|'array',
//     operator:'=='|'!='|'contains'|'startsWith'|'endsWith'|'in'|'not_in'|
//              '>'|'>='|'<'|'<='|'between'|
//              'is_true'|'is_false'|
//              'before'|'after'|'date_between'|
//              'array_contains'|'array_contains_any'|'array_contains_all',
//     value: dynamic,
//     value2: dynamic (between/date_between 用)
//   }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

class SegmentPreviewResult {
  final int scanned;
  final int matched;
  final List<Map<String, dynamic>> sampleUsers; // 含 uid

  SegmentPreviewResult({
    required this.scanned,
    required this.matched,
    required this.sampleUsers,
  });
}

class SegmentService {
  SegmentService._();

  // ============
  // Public APIs
  // ============

  static Map<String, dynamic> defaultRule() {
    return {
      'type': 'group',
      'op': 'and',
      'children': <dynamic>[
        {
          'type': 'condition',
          'field': 'role',
          'valueType': 'string',
          'operator': '==',
          'value': 'customer',
          'value2': null,
        }
      ],
    };
  }

  /// Preview：從 users 取樣 N 筆，做本地規則評估，回傳 matched/樣本清單
  static Future<SegmentPreviewResult> previewOnUsers({
    required Map<String, dynamic> rule,
    int limit = 500,
    int sampleLimit = 20,
  }) async {
    final fs = FirebaseFirestore.instance;
    final snap = await fs.collection('users').limit(limit).get();

    int matched = 0;
    final sample = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final u = <String, dynamic>{'uid': doc.id, ...doc.data()};
      final ok = evaluate(rule, u);
      if (ok) {
        matched++;
        if (sample.length < sampleLimit) {
          sample.add(u);
        }
      }
    }

    return SegmentPreviewResult(
      scanned: snap.size,
      matched: matched,
      sampleUsers: sample,
    );
  }

  /// 評估入口
  static bool evaluate(Map<String, dynamic>? node, Map<String, dynamic> user) {
    if (node == null || node.isEmpty) return true;
    final type = (node['type'] ?? 'group').toString();

    if (type == 'group') return _evalGroup(node, user);
    if (type == 'condition') return _evalCondition(node, user);

    // unknown node type => 不阻擋
    return true;
  }

  // ============
  // Group
  // ============

  static bool _evalGroup(Map<String, dynamic> node, Map<String, dynamic> user) {
    final op = (node['op'] ?? 'and').toString().toLowerCase();
    final children = (node['children'] as List?) ?? const [];

    if (children.isEmpty) return true;

    if (op == 'or') {
      for (final c in children) {
        if (c is Map<String, dynamic>) {
          if (evaluate(c, user)) return true;
        } else if (c is Map) {
          if (evaluate(c.map((k, v) => MapEntry(k.toString(), v)), user)) return true;
        }
      }
      return false;
    }

    // default and
    for (final c in children) {
      if (c is Map<String, dynamic>) {
        if (!evaluate(c, user)) return false;
      } else if (c is Map) {
        if (!evaluate(c.map((k, v) => MapEntry(k.toString(), v)), user)) return false;
      }
    }
    return true;
  }

  // ============
  // Condition
  // ============

  static bool _evalCondition(Map<String, dynamic> node, Map<String, dynamic> user) {
    final field = (node['field'] ?? '').toString().trim();
    if (field.isEmpty) return true;

    final valueType = (node['valueType'] ?? 'string').toString();
    final op = (node['operator'] ?? '==').toString();

    final userValue = _getByPath(user, field);

    final v1 = node['value'];
    final v2 = node['value2'];

    switch (valueType) {
      case 'number':
        return _evalNumber(op, userValue, v1, v2);
      case 'bool':
        return _evalBool(op, userValue);
      case 'date':
        return _evalDate(op, userValue, v1, v2);
      case 'array':
        return _evalArray(op, userValue, v1);
      case 'string':
      default:
        return _evalString(op, userValue, v1);
    }
  }

  // ============
  // Type evaluators
  // ============

  static bool _evalString(String op, dynamic userValue, dynamic v1) {
    final u = (userValue ?? '').toString();
    final s = (v1 ?? '').toString();

    switch (op) {
      case '==':
        return u == s;
      case '!=':
        return u != s;
      case 'contains':
        return u.toLowerCase().contains(s.toLowerCase());
      case 'startsWith':
        return u.toLowerCase().startsWith(s.toLowerCase());
      case 'endsWith':
        return u.toLowerCase().endsWith(s.toLowerCase());
      case 'in':
        final list = _toStringList(v1);
        return list.contains(u);
      case 'not_in':
        final list = _toStringList(v1);
        return !list.contains(u);
      default:
        // unknown operator => pass
        return true;
    }
  }

  static bool _evalNumber(String op, dynamic userValue, dynamic v1, dynamic v2) {
    final u = _toNum(userValue);
    final a = _toNum(v1);
    final b = _toNum(v2);

    switch (op) {
      case '==':
        return u == a;
      case '!=':
        return u != a;
      case '>':
        return u > a;
      case '>=':
        return u >= a;
      case '<':
        return u < a;
      case '<=':
        return u <= a;
      case 'between':
        final minV = a <= b ? a : b;
        final maxV = a <= b ? b : a;
        return u >= minV && u <= maxV;
      case 'in':
        final list = _toNumList(v1);
        return list.contains(u);
      case 'not_in':
        final list = _toNumList(v1);
        return !list.contains(u);
      default:
        return true;
    }
  }

  static bool _evalBool(String op, dynamic userValue) {
    final u = _toBool(userValue);
    switch (op) {
      case 'is_true':
        return u == true;
      case 'is_false':
        return u == false;
      case '==':
        return u == true; // 兼容舊資料
      default:
        return true;
    }
  }

  static bool _evalDate(String op, dynamic userValue, dynamic v1, dynamic v2) {
    final u = _toDate(userValue);
    if (u == null) return false;

    final a = _toDate(v1);
    final b = _toDate(v2);

    switch (op) {
      case 'before':
        if (a == null) return true;
        return u.isBefore(a);
      case 'after':
        if (a == null) return true;
        return u.isAfter(a);
      case 'date_between':
        if (a == null || b == null) return true;
        final minD = a.isBefore(b) ? a : b;
        final maxD = a.isBefore(b) ? b : a;
        return (u.isAfter(minD) || _sameDay(u, minD)) && (u.isBefore(maxD) || _sameDay(u, maxD));
      default:
        return true;
    }
  }

  static bool _evalArray(String op, dynamic userValue, dynamic v1) {
    final arr = _toDynamicList(userValue);
    if (arr == null) return false;

    final want = _toDynamicList(v1) ?? const [];

    switch (op) {
      case 'array_contains':
        return want.isEmpty ? true : arr.contains(want.first);
      case 'array_contains_any':
        for (final w in want) {
          if (arr.contains(w)) return true;
        }
        return false;
      case 'array_contains_all':
        for (final w in want) {
          if (!arr.contains(w)) return false;
        }
        return true;
      default:
        return true;
    }
  }

  // ============
  // Converters
  // ============

  static dynamic _getByPath(Map<String, dynamic> data, String path) {
    if (!path.contains('.')) return data[path];

    dynamic cur = data;
    for (final p in path.split('.')) {
      if (cur is Map) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  static num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'y';
    }
    if (v is num) return v != 0;
    return false;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      // 支援 yyyy-MM-dd / yyyy/MM/dd / ISO
      final s = v.trim();
      DateTime? d = DateTime.tryParse(s);
      if (d != null) return d;

      final s2 = s.replaceAll('/', '-');
      d = DateTime.tryParse(s2);
      return d;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      // comma-separated
      return v
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<num> _toNumList(dynamic v) {
    if (v is List) return v.map((e) => _toNum(e)).toList();
    if (v is String) {
      return v
          .split(',')
          .map((e) => _toNum(e.trim()))
          .toList();
    }
    return const [];
  }

  static List<dynamic>? _toDynamicList(dynamic v) {
    if (v is List) return v;
    if (v is String) {
      // comma-separated as strings
      final list = v
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return list;
    }
    return null;
  }
}
