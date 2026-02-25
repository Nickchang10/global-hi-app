// lib/services/ai_marketing_service.dart
//
// ✅ AiMarketingService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// ✅ 移除 FirestoreService（你現在的錯誤來源）
// ✅ 直接使用 FirebaseFirestore.instance / FirebaseAuth.instance
// ✅ 提供：
//    - 產生行銷文案草稿（標題/短文/長文/Hashtags）
//    - 儲存草稿到 Firestore
//    - 讀取我的草稿列表（Stream）
//    - 記錄使用者行為事件（曝光/點擊/分享）
// ----------------------------------------------------
//
// Firestore 建議結構（你可照用）：
// - users/{uid}
// - users/{uid}/ai_marketing_drafts/{draftId}
// - users/{uid}/ai_marketing_events/{eventId}
//
// 需要套件：cloud_firestore, firebase_auth
// ----------------------------------------------------

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AiMarketingDraftFields {
  static const String id = 'id';
  static const String uid = 'uid';

  static const String productId = 'productId';
  static const String productName = 'productName';
  static const String productCategory = 'productCategory';
  static const String price = 'price';
  static const String currency = 'currency';

  static const String audience = 'audience'; // 受眾：例如「親子」、「銀髮族」、「上班族」
  static const String tone = 'tone'; // 口吻：例如「專業」、「可愛」、「熱血」、「高級」
  static const String goal = 'goal'; // 目的：例如「導購」、「拉新」、「回購」、「活動宣傳」
  static const String channel = 'channel'; // 渠道：例如「Push」、「Line」、「FB」、「IG」

  static const String titles = 'titles'; // List<String>
  static const String shortCopies = 'shortCopies'; // List<String>
  static const String longCopies = 'longCopies'; // List<String>
  static const String hashtags = 'hashtags'; // List<String>

  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
}

class AiMarketingEventFields {
  static const String type = 'type'; // impression/click/share
  static const String channel = 'channel';
  static const String draftId = 'draftId';
  static const String productId = 'productId';
  static const String data = 'data';
  static const String createdAt = 'createdAt';
}

class AiMarketingDraft {
  final String id;
  final String uid;

  final String productId;
  final String productName;
  final String? productCategory;

  final num? price;
  final String currency;

  final String audience;
  final String tone;
  final String goal;
  final String channel;

  final List<String> titles;
  final List<String> shortCopies;
  final List<String> longCopies;
  final List<String> hashtags;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AiMarketingDraft({
    required this.id,
    required this.uid,
    required this.productId,
    required this.productName,
    required this.productCategory,
    required this.price,
    required this.currency,
    required this.audience,
    required this.tone,
    required this.goal,
    required this.channel,
    required this.titles,
    required this.shortCopies,
    required this.longCopies,
    required this.hashtags,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime? _toDate(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is DateTime) {
      return v;
    }
    return null;
  }

  static List<String> _toStrList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  factory AiMarketingDraft.fromSnap(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? <String, dynamic>{};
    return AiMarketingDraft(
      id: snap.id,
      uid: (d[AiMarketingDraftFields.uid] ?? '').toString(),
      productId: (d[AiMarketingDraftFields.productId] ?? '').toString(),
      productName: (d[AiMarketingDraftFields.productName] ?? '').toString(),
      productCategory: d[AiMarketingDraftFields.productCategory]?.toString(),
      price: d[AiMarketingDraftFields.price] is num
          ? d[AiMarketingDraftFields.price] as num
          : null,
      currency: (d[AiMarketingDraftFields.currency] ?? 'TWD').toString(),
      audience: (d[AiMarketingDraftFields.audience] ?? '一般').toString(),
      tone: (d[AiMarketingDraftFields.tone] ?? '專業').toString(),
      goal: (d[AiMarketingDraftFields.goal] ?? '導購').toString(),
      channel: (d[AiMarketingDraftFields.channel] ?? 'Push').toString(),
      titles: _toStrList(d[AiMarketingDraftFields.titles]),
      shortCopies: _toStrList(d[AiMarketingDraftFields.shortCopies]),
      longCopies: _toStrList(d[AiMarketingDraftFields.longCopies]),
      hashtags: _toStrList(d[AiMarketingDraftFields.hashtags]),
      createdAt: _toDate(d[AiMarketingDraftFields.createdAt]),
      updatedAt: _toDate(d[AiMarketingDraftFields.updatedAt]),
    );
  }

  Map<String, dynamic> toMapForSave() {
    return {
      AiMarketingDraftFields.uid: uid,
      AiMarketingDraftFields.productId: productId,
      AiMarketingDraftFields.productName: productName,
      AiMarketingDraftFields.productCategory: productCategory,
      AiMarketingDraftFields.price: price,
      AiMarketingDraftFields.currency: currency,
      AiMarketingDraftFields.audience: audience,
      AiMarketingDraftFields.tone: tone,
      AiMarketingDraftFields.goal: goal,
      AiMarketingDraftFields.channel: channel,
      AiMarketingDraftFields.titles: titles,
      AiMarketingDraftFields.shortCopies: shortCopies,
      AiMarketingDraftFields.longCopies: longCopies,
      AiMarketingDraftFields.hashtags: hashtags,
    };
  }
}

class AiMarketingService {
  AiMarketingService._({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final AiMarketingService instance = AiMarketingService._();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _draftsCol(String uid) =>
      _userRef(uid).collection('ai_marketing_drafts');

  CollectionReference<Map<String, dynamic>> _eventsCol(String uid) =>
      _userRef(uid).collection('ai_marketing_events');

  /// ✅ 監聽我的草稿列表（新到舊）
  Stream<List<AiMarketingDraft>> watchMyDrafts() {
    final uid = _uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _draftsCol(uid)
        .orderBy(AiMarketingDraftFields.createdAt, descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => AiMarketingDraft.fromSnap(d)).toList(),
        );
  }

  /// ✅ 產生草稿（本地規則生成，不依賴外部 AI）
  /// 你也可以之後改成 Cloud Functions / 你自己的 AI API，但這版可先讓專案編譯跑起來。
  Future<AiMarketingDraft> generateDraft({
    required String productId,
    required String productName,
    String? productCategory,
    num? price,
    String currency = 'TWD',
    String audience = '一般',
    String tone = '專業',
    String goal = '導購',
    String channel = 'Push',
    int variants = 3,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('User not logged in');
    }

    final v = variants.clamp(1, 5);
    final rng = Random();

    final priceText = (price == null) ? '' : ' $price $currency';
    final catText = (productCategory == null || productCategory.trim().isEmpty)
        ? ''
        : '｜${productCategory.trim()}';

    // 口吻調整用詞（很輕量，先求能用）
    String hook;
    String emoji;
    switch (tone.trim()) {
      case '可愛':
        hook = '超可愛必收';
        emoji = '✨';
        break;
      case '熱血':
        hook = '現在就衝';
        emoji = '🔥';
        break;
      case '高級':
        hook = '質感升級';
        emoji = '🖤';
        break;
      default:
        hook = '限時推薦';
        emoji = '⭐';
    }

    String cta;
    switch (goal.trim()) {
      case '拉新':
        cta = '新朋友快來看看';
        break;
      case '回購':
        cta = '老朋友回購更划算';
        break;
      case '活動宣傳':
        cta = '活動名額有限，別錯過';
        break;
      default:
        cta = '立即前往選購';
    }

    final titles = <String>[];
    final shortCopies = <String>[];
    final longCopies = <String>[];

    for (var i = 0; i < v; i++) {
      final n = rng.nextInt(3);
      final title = switch (n) {
        0 => '$emoji $hook：$productName$catText',
        1 => '$productName$catText｜$cta',
        _ => '$emoji $productName$priceText｜$hook',
      };
      titles.add(title);

      shortCopies.add('$productName$catText，${audience.trim()}首選。$cta！');

      longCopies.add(
        '【$productName$catText】$emoji\n'
        '為「${audience.trim()}」打造的精選推薦，主打「${tone.trim()}」風格，目標：${goal.trim()}。\n'
        '${price == null ? '' : '參考價：$priceText\n'}'
        '重點亮點：\n'
        '• 實用好上手\n'
        '• 品質與體驗兼顧\n'
        '• 適合日常/送禮\n'
        '\n$cta',
      );
    }

    final hashtags = _buildHashtags(
      productName: productName,
      category: productCategory,
      audience: audience,
      channel: channel,
      goal: goal,
    );

    final now = DateTime.now();
    return AiMarketingDraft(
      id: '',
      uid: uid,
      productId: productId,
      productName: productName,
      productCategory: productCategory,
      price: price,
      currency: currency,
      audience: audience,
      tone: tone,
      goal: goal,
      channel: channel,
      titles: titles,
      shortCopies: shortCopies,
      longCopies: longCopies,
      hashtags: hashtags,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// ✅ 儲存草稿到 Firestore，回傳 draftId
  Future<String> saveDraft(AiMarketingDraft draft) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('User not logged in');
    }

    final now = FieldValue.serverTimestamp();
    final ref = _draftsCol(uid).doc();

    await ref.set({
      ...draft.toMapForSave(),
      AiMarketingDraftFields.createdAt: now,
      AiMarketingDraftFields.updatedAt: now,
    }, SetOptions(merge: true));

    return ref.id;
  }

  /// ✅ 更新草稿（例如你在 UI 編輯後儲存）
  Future<void> updateDraft({
    required String draftId,
    List<String>? titles,
    List<String>? shortCopies,
    List<String>? longCopies,
    List<String>? hashtags,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('User not logged in');
    }

    final patch = <String, dynamic>{
      AiMarketingDraftFields.updatedAt: FieldValue.serverTimestamp(),
    };

    if (titles != null) {
      patch[AiMarketingDraftFields.titles] = titles;
    }
    if (shortCopies != null) {
      patch[AiMarketingDraftFields.shortCopies] = shortCopies;
    }
    if (longCopies != null) {
      patch[AiMarketingDraftFields.longCopies] = longCopies;
    }
    if (hashtags != null) {
      patch[AiMarketingDraftFields.hashtags] = hashtags;
    }

    await _draftsCol(uid).doc(draftId).update(patch);
  }

  /// ✅ 刪除草稿
  Future<void> deleteDraft(String draftId) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('User not logged in');
    }
    await _draftsCol(uid).doc(draftId).delete();
  }

  /// ✅ 記錄行為事件（曝光/點擊/分享）
  Future<void> trackEvent({
    required String type, // impression / click / share
    String? channel,
    String? draftId,
    String? productId,
    Map<String, dynamic>? data,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }

    await _eventsCol(uid).add({
      AiMarketingEventFields.type: type,
      AiMarketingEventFields.channel: channel,
      AiMarketingEventFields.draftId: draftId,
      AiMarketingEventFields.productId: productId,
      AiMarketingEventFields.data: data ?? <String, dynamic>{},
      AiMarketingEventFields.createdAt: FieldValue.serverTimestamp(),
    });
  }

  // ---------- Private ----------

  List<String> _buildHashtags({
    required String productName,
    required String? category,
    required String audience,
    required String channel,
    required String goal,
  }) {
    final base = <String>{
      '#Osmile',
      '#優惠',
      '#熱賣',
      '#推薦',
      '#${_safeTag(audience)}',
      '#${_safeTag(channel)}',
      '#${_safeTag(goal)}',
      if (category != null && category.trim().isNotEmpty)
        '#${_safeTag(category)}',
    };

    // 產品名太長就不硬塞 hashtag
    final pn = productName.trim();
    if (pn.isNotEmpty && pn.length <= 10) {
      base.add('#${_safeTag(pn)}');
    }

    return base.toList(growable: false);
  }

  String _safeTag(String s) {
    // 移除空白與特殊符號，避免 hashtag 亂掉
    final cleaned = s
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^0-9A-Za-z\u4e00-\u9fa5_]'), '');
    return cleaned.isEmpty ? 'Tag' : cleaned;
  }
}
