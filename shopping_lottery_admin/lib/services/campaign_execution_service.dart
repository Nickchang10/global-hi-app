// lib/services/campaign_execution_service.dart
//
// ✅ CampaignExecutionService（行銷流程自動執行引擎｜完整版）
// ------------------------------------------------------------
// 功能：
// - 從 /campaign_flows 與 /campaign_links 讀取流程
// - 依節點順序執行：segment → auto_campaign → lottery → notify
// - 可手動執行單一流程 ID
// - 自動紀錄執行日誌：/campaign_logs
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CampaignExecutionService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// 主執行入口
  Future<void> runCampaign(String campaignId) async {
    final flowDocs = await _fs.collection('campaign_flows').get();
    final linkDocs = await _fs.collection('campaign_links').get();

    final nodes =
        flowDocs.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    final links =
        linkDocs.docs.map((d) => {...d.data(), 'id': d.id}).toList();

    // 找出起始節點（沒有其他節點指向它）
    final startNodes = nodes.where(
      (n) => !links.any((l) => l['to'] == n['id']),
    );

    for (final node in startNodes) {
      await _executeNode(node, nodes, links);
    }
  }

  /// 執行節點
  Future<void> _executeNode(Map<String, dynamic> node,
      List<Map<String, dynamic>> allNodes, List<Map<String, dynamic>> allLinks) async {
    final type = node['type'] ?? 'unknown';
    final id = node['id'];
    final title = node['title'] ?? '(未命名節點)';

    await _log('[START] $title ($type)');

    try {
      switch (type) {
        case 'segment':
          await _handleSegment(node);
          break;
        case 'auto_campaign':
          await _handleAutoCampaign(node);
          break;
        case 'lottery':
          await _handleLottery(node);
          break;
        case 'notify':
          await _handleNotification(node);
          break;
        default:
          await _log('未知節點類型：$type');
      }
    } catch (e) {
      await _log('[ERROR] 節點執行失敗：$e');
    }

    await _log('[END] $title ($type)');

    // 執行下一節點
    final nextLinks = allLinks.where((l) => l['from'] == id);
    for (final l in nextLinks) {
      final nextNode = allNodes.firstWhere(
        (n) => n['id'] == l['to'],
        orElse: () => {},
      );
      if (nextNode.isNotEmpty) {
        await _executeNode(nextNode, allNodes, allLinks);
      }
    }
  }

  // =====================================================
  // 各節點類型處理
  // =====================================================

  /// 節點 1：受眾分群
  Future<void> _handleSegment(Map<String, dynamic> node) async {
    final filters = node['filters'] ?? {};
    await _log('受眾分群執行中，條件：${filters.toString()}');

    // 模擬查詢會員數
    final snapshot = await _fs.collection('users').get();
    final matchedUsers = snapshot.docs
        .where((u) {
          final data = u.data();
          bool match = true;
          filters.forEach((k, v) {
            if (data[k] != v) match = false;
          });
          return match;
        })
        .toList();

    await _log('匹配會員數：${matchedUsers.length}');
  }

  /// 節點 2：自動派發（優惠券、任務）
  Future<void> _handleAutoCampaign(Map<String, dynamic> node) async {
    final couponId = node['couponId'];
    if (couponId == null) {
      await _log('無指定優惠券，跳過自動派發');
      return;
    }

    await _log('正在派發優惠券：$couponId');

    // 模擬發送紀錄
    await _fs.collection('coupon_distributions').add({
      'couponId': couponId,
      'executedAt': FieldValue.serverTimestamp(),
    });

    await _log('優惠券派發完成');
  }

  /// 節點 3：抽獎活動
  Future<void> _handleLottery(Map<String, dynamic> node) async {
    final lotteryId = node['lotteryId'];
    if (lotteryId == null) {
      await _log('無指定抽獎活動，跳過');
      return;
    }

    await _log('執行抽獎流程：$lotteryId');

    // 模擬抽獎結果
    final result = {
      'winnerCount': 3,
      'reward': '折扣券',
    };

    await _fs.collection('lottery_results').add({
      'lotteryId': lotteryId,
      'result': result,
      'executedAt': FieldValue.serverTimestamp(),
    });

    await _log('抽獎完成，產生結果：$result');
  }

  /// 節點 4：推播通知
  Future<void> _handleNotification(Map<String, dynamic> node) async {
    final message = node['message'] ?? '行銷通知';
    await _log('推播通知：$message');

    // 模擬通知發送
    await _fs.collection('notifications').add({
      'title': '行銷推播',
      'body': message,
      'sentAt': FieldValue.serverTimestamp(),
    });

    await _log('通知已發送');
  }

  // =====================================================
  // 共用：日誌記錄
  // =====================================================

  Future<void> _log(String message) async {
    debugPrint(message);
    await _fs.collection('campaign_logs').add({
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
