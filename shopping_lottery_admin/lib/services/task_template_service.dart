// lib/services/task_template_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskTemplateService {
  final FirebaseFirestore _db;
  TaskTemplateService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('task_templates');

  /// Admin：看全部（含停用）
  Stream<List<Map<String, dynamic>>> streamAll() {
    return _col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Vendor：只看「啟用」+ (audience=all/vendor)
  Stream<List<Map<String, dynamic>>> streamForVendor() {
    return _col
        .where('isActive', isEqualTo: true)
        .where('audience', whereIn: const ['all', 'vendor'])
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...(snap.data() ?? {})};
  }

  Future<void> upsert({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _col.doc(id).set(
      {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> create(Map<String, dynamic> data) async {
    final doc = await _col.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _col.doc(id).set(
      {
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// 若 collection 為空，寫入一組預設範本
  Future<void> ensureDefaultTemplates() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    final defaults = <Map<String, dynamic>>[
      {
        'title': '新訂單處理流程',
        'description': '收到訂單後的標準處理步驟（含對帳、出貨、通知）',
        'category': 'order',
        'priority': 'high', // low/medium/high
        'dueDays': 1,
        'audience': 'all', // all/admin/vendor
        'checklist': [
          '確認付款狀態',
          '確認收件資訊',
          '備貨與包裝',
          '建立出貨單 / 物流單',
          '通知客戶出貨',
        ],
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      },
      {
        'title': '客服回覆範本更新',
        'description': '每週更新 FAQ 與客服話術，確保一致性',
        'category': 'support',
        'priority': 'medium',
        'dueDays': 7,
        'audience': 'admin',
        'checklist': [
          '收集本週高頻問題',
          '更新話術範本',
          '公告變更給客服/營運',
        ],
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      },
      {
        'title': '商品上架檢查',
        'description': 'Vendor 上架前自檢（圖片、價格、分類、說明）',
        'category': 'product',
        'priority': 'medium',
        'dueDays': 0,
        'audience': 'vendor',
        'checklist': [
          '圖片連結可開啟',
          '價格與規格正確',
          '分類正確',
          '商品標題清楚',
        ],
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      },
    ];

    for (final t in defaults) {
      final ref = _col.doc(); // auto id
      batch.set(ref, t);
    }

    await batch.commit();
  }
}
