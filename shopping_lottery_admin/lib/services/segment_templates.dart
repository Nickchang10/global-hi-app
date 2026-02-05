// lib/services/segment_templates.dart
//
// ✅ Segment Templates (範本)
// ------------------------------------------------------------
// 預設分群範本 (例如：新客、高價值、未活躍、生日月)
// 每個範本為一個可直接寫入 Firestore 的 rule 結構。
// ------------------------------------------------------------

class SegmentTemplates {
  static Map<String, dynamic> newCustomer() => {
        'type': 'group',
        'op': 'and',
        'children': [
          {
            'type': 'condition',
            'field': 'stats.orderCount',
            'valueType': 'number',
            'operator': '<=',
            'value': 1,
          },
          {
            'type': 'condition',
            'field': 'createdAt',
            'valueType': 'date',
            'operator': 'after',
            'value': DateTime.now()
                .subtract(const Duration(days: 30))
                .toIso8601String(),
          },
        ],
      };

  static Map<String, dynamic> highValue() => {
        'type': 'group',
        'op': 'and',
        'children': [
          {
            'type': 'condition',
            'field': 'stats.totalSpent',
            'valueType': 'number',
            'operator': '>=',
            'value': 5000,
          },
          {
            'type': 'condition',
            'field': 'stats.orderCount',
            'valueType': 'number',
            'operator': '>=',
            'value': 3,
          },
        ],
      };

  static Map<String, dynamic> inactive7Days() => {
        'type': 'group',
        'op': 'and',
        'children': [
          {
            'type': 'condition',
            'field': 'lastActiveAt',
            'valueType': 'date',
            'operator': 'before',
            'value': DateTime.now()
                .subtract(const Duration(days: 7))
                .toIso8601String(),
          },
        ],
      };

  static Map<String, dynamic> birthdayMonth() => {
        'type': 'group',
        'op': 'and',
        'children': [
          {
            'type': 'condition',
            'field': 'profile.birthday',
            'valueType': 'date',
            'operator': 'date_between',
            'value': DateTime.now()
                .subtract(const Duration(days: 15))
                .toIso8601String(),
            'value2': DateTime.now()
                .add(const Duration(days: 15))
                .toIso8601String(),
          },
        ],
      };

  static List<Map<String, dynamic>> allTemplates() => [
        {'id': 'new_customer', 'name': '新客（近30天註冊）', 'rule': newCustomer()},
        {'id': 'high_value', 'name': '高價值客戶（消費高）', 'rule': highValue()},
        {'id': 'inactive', 'name': '未活躍用戶（7天未登入）', 'rule': inactive7Days()},
        {'id': 'birthday', 'name': '生日月用戶', 'rule': birthdayMonth()},
      ];
}
