// lib/services/campaign_notifier.dart
//
// ✅ CampaignNotifier（最終完整版本｜活動通知整合服務）
// ------------------------------------------------------------
// 功能：
// - 當活動新增、啟用、停用、自動推播至 NotificationService / Firestore
// - 與後台通知中心共用同一集合（notifications）
// - 支援 Admin/Vendor 角色差異（Admin：全站；Vendor：綁自己 vendorId）
// ------------------------------------------------------------
//
// Firestore 結構：notifications/{id}
// - title: string
// - message: string
// - target: 'all' / 'admin' / 'vendor:{vendorId}'
// - createdAt: timestamp
// - readBy: [] (userId array)
// - campaignId: string?
// - type: 'campaign'
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'admin_gate.dart';

class CampaignNotifier {
  CampaignNotifier({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AdminGate? adminGate,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _gate = adminGate ?? AdminGate();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final AdminGate _gate;

  /// 🔹 發送活動通知
  /// [action] 可為 'created' / 'updated' / 'activated' / 'deactivated'
  Future<void> sendCampaignNotification({
    required String campaignId,
    required String title,
    required String action,
    String? vendorId,
  }) async {
    try {
      final user = _auth.currentUser;
      final roleInfo =
          user == null ? RoleInfo.empty() : await _gate.ensureAndGetRole(user);

      final now = FieldValue.serverTimestamp();
      String message;
      String target;

      switch (action) {
        case 'created':
          message = '🎉 新活動「$title」已建立';
          break;
        case 'updated':
          message = '✏️ 活動「$title」已更新內容';
          break;
        case 'activated':
          message = '✅ 活動「$title」已啟用';
          break;
        case 'deactivated':
          message = '⛔ 活動「$title」已停用';
          break;
        default:
          message = '📢 活動「$title」更新';
      }

      if (roleInfo.isAdmin) {
        // Admin 建立：發給全站使用者
        target = 'all';
      } else if (roleInfo.isVendor) {
        // Vendor 建立：限定自己 vendor
        target = 'vendor:${roleInfo.vendorId ?? vendorId ?? 'unknown'}';
      } else {
        // 其他角色無權限發送
        return;
      }

      await _db.collection('notifications').add({
        'title': '活動通知',
        'message': message,
        'target': target,
        'type': 'campaign',
        'campaignId': campaignId,
        'createdAt': now,
        'readBy': [],
      });

      if (kDebugMode) {
        debugPrint('[CampaignNotifier] 已發送活動通知：$message ($target)');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CampaignNotifier] 發送失敗：$e\n$st');
      }
    }
  }

  /// 🔹 當活動新增時呼叫
  Future<void> onCampaignCreated({
    required String campaignId,
    required String title,
    String? vendorId,
  }) =>
      sendCampaignNotification(
        campaignId: campaignId,
        title: title,
        action: 'created',
        vendorId: vendorId,
      );

  /// 🔹 當活動更新/編輯後呼叫
  Future<void> onCampaignUpdated({
    required String campaignId,
    required String title,
    String? vendorId,
  }) =>
      sendCampaignNotification(
        campaignId: campaignId,
        title: title,
        action: 'updated',
        vendorId: vendorId,
      );

  /// 🔹 當活動啟用
  Future<void> onCampaignActivated({
    required String campaignId,
    required String title,
    String? vendorId,
  }) =>
      sendCampaignNotification(
        campaignId: campaignId,
        title: title,
        action: 'activated',
        vendorId: vendorId,
      );

  /// 🔹 當活動停用
  Future<void> onCampaignDeactivated({
    required String campaignId,
    required String title,
    String? vendorId,
  }) =>
      sendCampaignNotification(
        campaignId: campaignId,
        title: title,
        action: 'deactivated',
        vendorId: vendorId,
      );
}
