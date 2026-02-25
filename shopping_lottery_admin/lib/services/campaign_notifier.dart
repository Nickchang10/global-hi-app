// lib/services/campaign_notifier.dart
//
// ✅ CampaignNotifier（活動/行銷 Notifier｜可編譯完整版｜修正 dead_code）
// ------------------------------------------------------------
// - Provider / ChangeNotifier 用
// - Firestore collection 預設：campaigns
// - 支援：載入列表、監聽、建立/更新/刪除、狀態切換、篩選 vendorId
//
// 你可以在 UI 端用：
// context.watch<CampaignNotifier>().campaigns
// context.read<CampaignNotifier>().init(vendorId: 'xxx')
//
// ✅ 本檔自帶 Campaign model（避免缺 model 編譯失敗）
// 若你專案已有 model，可保留 Notifier，移除 model 區塊並改 import 你的 model。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ------------------------------------------------------------
/// Model: Campaign（簡化版，足夠支援列表/編輯/報表）
/// ------------------------------------------------------------
@immutable
class Campaign {
  final String id;
  final String vendorId;

  final String name;
  final String description;

  /// draft | active | paused | ended | archived
  final String status;

  /// 例：2026-02-01 00:00:00 ~ 2026-02-29 23:59:59
  final DateTime? startAt;
  final DateTime? endAt;

  /// 用於自動化活動或流程建構器（可選）
  /// - builder: {nodes:[], edges:[], version:1}
  final Map<String, dynamic> builder;

  /// 報表/彙總（可選）
  final Map<String, dynamic> metrics;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const Campaign({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.status,
    required this.builder,
    required this.metrics,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.startAt,
    this.endAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  factory Campaign.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return Campaign(
      id: doc.id,
      vendorId: _s(data['vendorId']),
      name: _s(data['name']).isNotEmpty ? _s(data['name']) : _s(data['title']),
      description: _s(data['description']).isNotEmpty
          ? _s(data['description'])
          : _s(data['body']),
      status: _s(data['status']).isEmpty ? 'draft' : _s(data['status']),
      startAt: _toDate(data['startAt']),
      endAt: _toDate(data['endAt']),
      builder: _asMap(data['builder']),
      metrics: _asMap(data['metrics']),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      createdBy: _s(data['createdBy']),
    );
  }

  Map<String, dynamic> toJsonForWrite() {
    return <String, dynamic>{
      'vendorId': vendorId,
      'name': name,
      'description': description,
      'status': status,
      'builder': builder,
      'metrics': metrics,
      if (startAt != null) 'startAt': Timestamp.fromDate(startAt!),
      if (endAt != null) 'endAt': Timestamp.fromDate(endAt!),
      if (createdBy.isNotEmpty) 'createdBy': createdBy,
    };
  }

  Campaign copyWith({
    String? vendorId,
    String? name,
    String? description,
    String? status,
    DateTime? startAt,
    DateTime? endAt,
    Map<String, dynamic>? builder,
    Map<String, dynamic>? metrics,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Campaign(
      id: id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      builder: builder ?? this.builder,
      metrics: metrics ?? this.metrics,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// ------------------------------------------------------------
/// Notifier: CampaignNotifier
/// ------------------------------------------------------------
class CampaignNotifier extends ChangeNotifier {
  final FirebaseFirestore _db;
  final String collectionPath;

  CampaignNotifier({FirebaseFirestore? db, this.collectionPath = 'campaigns'})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collectionPath);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  bool _loading = false;
  String? _error;

  String _vendorId = '';
  List<Campaign> _campaigns = const [];

  bool get loading => _loading;
  String? get error => _error;
  String get vendorId => _vendorId;
  List<Campaign> get campaigns => _campaigns;

  /// 讓 UI 可快速拿到「可見活動」（active/paused）
  List<Campaign> get visibleCampaigns {
    final list = _campaigns;
    return list.where((c) {
      final s = c.status.toLowerCase();
      return s == 'active' || s == 'paused';
    }).toList();
  }

  /// ----------------------------------------------------------
  /// 初始化 / 監聽（可重複呼叫會自動切換 vendorId）
  /// ----------------------------------------------------------
  Future<void> init({
    String vendorId = '',
    int limit = 200,
    bool listen = true,
  }) async {
    final vid = vendorId.trim();
    final changedVendor = vid != _vendorId;

    // 若 vendor 變了，先取消舊訂閱（避免多重監聽）
    if (changedVendor) {
      await _sub?.cancel();
      _sub = null;
      _campaigns = const [];
    }

    _vendorId = vid;

    // 單純不 listen 也能手動 refresh
    if (!listen) {
      await refresh(limit: limit);
      return;
    }

    _setLoading(true);
    _setError(null);

    Query<Map<String, dynamic>> q = _col.orderBy('updatedAt', descending: true);

    if (_vendorId.isNotEmpty) {
      q = q.where('vendorId', isEqualTo: _vendorId);
    }

    q = q.limit(limit);

    // ✅ 修正 dead_code：不做任何 return 後還寫程式的結構
    _sub = q.snapshots().listen(
      (snap) {
        final list = snap.docs.map(Campaign.fromDoc).toList();
        _campaigns = list;
        _setLoading(false);
        // 這裡需要 notify
        notifyListeners();
      },
      onError: (e) {
        _setError('$e');
        _setLoading(false);
        notifyListeners();
      },
    );
  }

  /// 手動刷新（不依賴訂閱）
  Future<void> refresh({int limit = 200}) async {
    _setLoading(true);
    _setError(null);
    notifyListeners();

    try {
      Query<Map<String, dynamic>> q = _col.orderBy(
        'updatedAt',
        descending: true,
      );

      if (_vendorId.isNotEmpty) {
        q = q.where('vendorId', isEqualTo: _vendorId);
      }

      q = q.limit(limit);

      final snap = await q.get();
      _campaigns = snap.docs.map(Campaign.fromDoc).toList();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('$e');
      _setLoading(false);
      notifyListeners();
    }
  }

  /// ----------------------------------------------------------
  /// CRUD
  /// ----------------------------------------------------------
  Future<String> createCampaign({
    required String name,
    String description = '',
    String vendorId = '',
    String status = 'draft',
    DateTime? startAt,
    DateTime? endAt,
    Map<String, dynamic> builder = const {},
    Map<String, dynamic> metrics = const {},
    String createdBy = '',
  }) async {
    final now = FieldValue.serverTimestamp();
    final vid = (vendorId.trim().isNotEmpty ? vendorId.trim() : _vendorId);

    final data = <String, dynamic>{
      'vendorId': vid,
      'name': name.trim(),
      'description': description.trim(),
      'status': status.trim().isEmpty ? 'draft' : status.trim(),
      'builder': Map<String, dynamic>.from(builder),
      'metrics': Map<String, dynamic>.from(metrics),
      if (startAt != null) 'startAt': Timestamp.fromDate(startAt),
      if (endAt != null) 'endAt': Timestamp.fromDate(endAt),
      if (createdBy.trim().isNotEmpty) 'createdBy': createdBy.trim(),
      'createdAt': now,
      'updatedAt': now,
    };

    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> updateCampaign(String id, Campaign campaign) async {
    await _col.doc(id).set({
      ...campaign.toJsonForWrite(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> patchCampaign(String id, Map<String, dynamic> patch) async {
    await _col.doc(id).set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteCampaign(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> setStatus(String id, String status) async {
    await _col.doc(id).set({
      'status': status.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// ----------------------------------------------------------
  /// 工具：取單筆 / 本地查找
  /// ----------------------------------------------------------
  Campaign? findLocalById(String id) {
    try {
      return _campaigns.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Campaign?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Campaign.fromDoc(doc);
  }

  /// ----------------------------------------------------------
  /// 清理
  /// ----------------------------------------------------------
  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  /// ----------------------------------------------------------
  /// Private setters
  /// ----------------------------------------------------------
  void _setLoading(bool v) {
    _loading = v;
  }

  void _setError(String? v) {
    _error = v;
  }
}
