// lib/services/segment_field_dictionary.dart
//
// ✅ Segments Field Dictionary
// ------------------------------------------------------------
// 定義行銷系統分群可用的欄位 (Field)。
// 每個欄位包含：id, label, valueType, path, description。
// ------------------------------------------------------------

class SegmentField {
  final String id;
  final String label;
  final String valueType; // string, number, bool, date, array
  final String path;
  final String description;

  const SegmentField({
    required this.id,
    required this.label,
    required this.valueType,
    required this.path,
    required this.description,
  });
}

class SegmentFieldDictionary {
  static const fields = <SegmentField>[
    SegmentField(
      id: 'role',
      label: '角色 (Role)',
      valueType: 'string',
      path: 'role',
      description: '用戶角色，例如 customer / vendor / admin',
    ),
    SegmentField(
      id: 'createdAt',
      label: '註冊日期',
      valueType: 'date',
      path: 'createdAt',
      description: '用戶建立帳號的時間',
    ),
    SegmentField(
      id: 'lastActiveAt',
      label: '最近活躍時間',
      valueType: 'date',
      path: 'lastActiveAt',
      description: '用戶最近登入或互動時間',
    ),
    SegmentField(
      id: 'totalOrders',
      label: '總訂單數',
      valueType: 'number',
      path: 'stats.orderCount',
      description: '已完成的訂單數量',
    ),
    SegmentField(
      id: 'totalSpent',
      label: '總消費金額',
      valueType: 'number',
      path: 'stats.totalSpent',
      description: '用戶累計的消費金額 (NTD)',
    ),
    SegmentField(
      id: 'birthday',
      label: '生日',
      valueType: 'date',
      path: 'profile.birthday',
      description: '用戶生日日期',
    ),
    SegmentField(
      id: 'city',
      label: '城市',
      valueType: 'string',
      path: 'profile.city',
      description: '用戶居住城市',
    ),
    SegmentField(
      id: 'tags',
      label: '標籤',
      valueType: 'array',
      path: 'tags',
      description: '用戶標籤（例如 VIP, repeat_buyer）',
    ),
    SegmentField(
      id: 'hasCoupon',
      label: '是否持有優惠券',
      valueType: 'bool',
      path: 'flags.hasCoupon',
      description: '是否有未使用的優惠券',
    ),
  ];

  static SegmentField? getById(String id) {
    return fields.firstWhere((f) => f.id == id, orElse: () => fields.first);
  }

  static List<String> get allFieldIds => fields.map((f) => f.id).toList();
}
