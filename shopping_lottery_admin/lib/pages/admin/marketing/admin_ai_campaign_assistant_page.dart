import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ AdminAICampaignAssistantPage（AI 行銷策略生成器｜完整版｜可編譯）
/// ------------------------------------------------------------
/// 功能：
/// - 讀取 segments（受眾分群）
/// - 選擇目標 / 通路 / 期間 / 活動型態（優惠券/抽獎/兩者/自動派發）
/// - 一鍵生成「行銷方案草稿」：
///   - marketing_plans：保存 AI 建議、參數、預估指標、關聯資源ID
///   - coupons（可選）：建立草稿券（isActive=false）
///   - lotteries（可選）：建立草稿抽獎（isActive=false）
///   - auto_campaigns（可選）：建立草稿自動派發（isActive=false）
/// - 最近方案列表（可刪除、可快速跳轉到編輯頁）
///
/// 注意：
/// - 本頁不依賴你其他 services，直接使用 Firestore
/// - 欄位命名採用「容錯模式」：你現有資料若欄位不同也不會炸（讀取採 ??）
class AdminAICampaignAssistantPage extends StatefulWidget {
  const AdminAICampaignAssistantPage({super.key});

  @override
  State<AdminAICampaignAssistantPage> createState() =>
      _AdminAICampaignAssistantPageState();
}

class _AdminAICampaignAssistantPageState
    extends State<AdminAICampaignAssistantPage> {
  // -----------------------------
  // Form state
  // -----------------------------
  bool _loadingSegments = true;
  bool _creating = false;

  List<_SegmentItem> _segments = [];
  _SegmentItem? _selectedSegment;

  final _planTitleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _goal = _Goal.items.first;
  String _channel = _Channel.items.first;
  String _bundle = _Bundle.items.first; // coupon / lottery / both / auto / full

  DateTime _startAt = DateTime.now();
  DateTime _endAt = DateTime.now().add(const Duration(days: 14));

  // AI output preview (generated)
  _AIPreview? _preview;

  @override
  void initState() {
    super.initState();
    _planTitleCtrl.text = '新行銷方案';
    _loadSegments();
  }

  @override
  void dispose() {
    _planTitleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // -----------------------------
  // Firestore
  // -----------------------------
  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  Future<void> _loadSegments() async {
    setState(() => _loadingSegments = true);
    try {
      final snap = await _fs
          .collection('segments')
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();

      final list = <_SegmentItem>[];
      for (final d in snap.docs) {
        final data = d.data();
        list.add(
          _SegmentItem(
            id: d.id,
            title: (data['title'] ?? data['name'] ?? '未命名分群').toString(),
            // 常見欄位：previewCount / userCount / estimatedSize
            size: _asInt(data['previewCount'] ?? data['userCount'] ?? data['estimatedSize']),
            // 常見欄位：conversionRate（0~1 或 0~100）
            conversionRate: _normalizeRate(data['conversionRate']),
            description: (data['description'] ?? data['desc'] ?? '').toString(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _segments = list;
        _selectedSegment = list.isNotEmpty ? list.first : null;
        _loadingSegments = false;
      });

      // 先自動生成一次預覽
      _generatePreview();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSegments = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('讀取分群失敗：$e')));
    }
  }

  // -----------------------------
  // AI (heuristics) preview
  // -----------------------------
  void _generatePreview() {
    final seg = _selectedSegment;
    final title = _planTitleCtrl.text.trim().isEmpty ? '新行銷方案' : _planTitleCtrl.text.trim();

    final baseRate = seg?.conversionRate ?? 0.8; // %
    final size = seg?.size ?? 0;

    // 依目標/通路/組合做一點可理解的規則加權
    final goalBoost = _Goal.boost(_goal);
    final channelBoost = _Channel.boost(_channel);
    final bundleBoost = _Bundle.boost(_bundle);

    // 預估 lift：基礎 + 加權 + 微量噪聲
    final rng = Random();
    final predictedLiftPct = (2.0 + goalBoost + channelBoost + bundleBoost + rng.nextDouble() * 2.0)
        .clamp(0, 25)
        .toDouble();

    // 預估 ROI：大致跟 lift、通路效率、組合複雜度有關
    final expectedRoi = (1.1 + (predictedLiftPct / 20.0) + _Channel.roiBias(_channel) - _Bundle.costPenalty(_bundle))
        .clamp(0.8, 4.5)
        .toDouble();

    // 預估 conversions：用 size、baseRate、lift 推估
    // baseRate 是百分比；lift 也是百分比
    final estimatedConversions = (size <= 0)
        ? max(5, (baseRate * 10).round())
        : max(1, ((size * (baseRate / 100.0)) * (1.0 + predictedLiftPct / 100.0)).round());

    // 建議內容（可直接存 marketing_plans）
    final bullets = _buildBullets(goal: _goal, channel: _channel, bundle: _bundle, baseRate: baseRate);

    // 優惠券草稿建議
    final couponSuggestion = _buildCouponSuggestion(_goal);
    // 抽獎草稿建議
    final lotterySuggestion = _buildLotterySuggestion(_goal);

    setState(() {
      _preview = _AIPreview(
        planTitle: title,
        segmentTitle: seg?.title ?? '（未選擇分群）',
        segmentSize: size,
        baseConversionRatePct: baseRate,
        predictedLiftPct: predictedLiftPct,
        expectedRoiX: expectedRoi,
        estimatedConversions: estimatedConversions,
        bullets: bullets,
        couponSuggestion: couponSuggestion,
        lotterySuggestion: lotterySuggestion,
      );
    });
  }

  List<String> _buildBullets({
    required String goal,
    required String channel,
    required String bundle,
    required double baseRate,
  }) {
    final tips = <String>[];

    tips.add('目標：${_Goal.label(goal)}；通路：${_Channel.label(channel)}；組合：${_Bundle.label(bundle)}。');

    if (baseRate < 1.0) {
      tips.add('分群基礎轉換偏低（${baseRate.toStringAsFixed(1)}%），建議先用「低門檻誘因 + 再喚醒」提高回流。');
    } else if (baseRate < 3.0) {
      tips.add('分群基礎轉換中等（${baseRate.toStringAsFixed(1)}%），建議以「限時 + 明確利益點」提升決策速度。');
    } else {
      tips.add('分群基礎轉換較高（${baseRate.toStringAsFixed(1)}%），可測試「加價購/升級」或「高價值券」放大 ROI。');
    }

    if (channel == _Channel.push) {
      tips.add('Push：建議分兩波（首波觸達 + 48 小時未轉換補推），並以短標題 + 單一 CTA。');
    } else if (channel == _Channel.line) {
      tips.add('LINE：建議使用「圖文卡 + 按鈕」；連結帶 couponCode 參數以利追蹤。');
    } else if (channel == _Channel.email) {
      tips.add('Email：建議 A/B 測試主旨（利益點 vs 限時），並在首屏放 CTA。');
    } else if (channel == _Channel.sms) {
      tips.add('SMS：建議內容極短（<= 70 字），連結使用短網址並加 UTM。');
    } else if (channel == _Channel.inApp) {
      tips.add('In-App：建議搭配「進站彈窗 + 置頂 banner」並限制頻率避免干擾。');
    }

    if (bundle == _Bundle.coupon) {
      tips.add('優惠券：建議設定最低消費門檻，避免純折扣侵蝕毛利。');
    } else if (bundle == _Bundle.lottery) {
      tips.add('抽獎：建議以「任務式參與」提升互動（點擊/分享/加入收藏等）。');
    } else if (bundle == _Bundle.both) {
      tips.add('券 + 抽獎：先用券促轉，未轉換者再導入抽獎提升互動與回訪。');
    } else if (bundle == _Bundle.auto) {
      tips.add('自動派發：建議以事件觸發（加購物車未結帳 / 7 日未回訪）做個人化派券。');
    } else if (bundle == _Bundle.full) {
      tips.add('全功能：建議以「分群 → 自動派發 → 券促轉 → 抽獎留存」串成完整漏斗。');
    }

    return tips;
  }

  Map<String, dynamic> _buildCouponSuggestion(String goal) {
    // 你可依商品毛利調整這些預設
    final rng = Random();
    final code = 'OSM${(100000 + rng.nextInt(899999))}';
    if (goal == _Goal.reactivate) {
      return {
        'title': '回流專屬折扣券',
        'code': code,
        'discountType': 'percent', // percent | amount
        'discountValue': 12,
        'minSpend': 499,
        'issuedLimit': 999999,
      };
    }
    if (goal == _Goal.acquire) {
      return {
        'title': '新客首購優惠券',
        'code': code,
        'discountType': 'amount',
        'discountValue': 80,
        'minSpend': 699,
        'issuedLimit': 999999,
      };
    }
    if (goal == _Goal.engage) {
      return {
        'title': '互動任務獎勵券',
        'code': code,
        'discountType': 'amount',
        'discountValue': 50,
        'minSpend': 499,
        'issuedLimit': 999999,
      };
    }
    // convert
    return {
      'title': '限時轉換券',
      'code': code,
      'discountType': 'percent',
      'discountValue': 10,
      'minSpend': 599,
      'issuedLimit': 999999,
    };
  }

  Map<String, dynamic> _buildLotterySuggestion(String goal) {
    if (goal == _Goal.engage) {
      return {
        'title': '互動抽獎：完成任務抽好禮',
        'winnerCount': 10,
        'prizeTitle': '品牌好禮/配件',
      };
    }
    if (goal == _Goal.reactivate) {
      return {
        'title': '回流抽獎：回來就抽',
        'winnerCount': 8,
        'prizeTitle': '折扣碼/小禮物',
      };
    }
    if (goal == _Goal.acquire) {
      return {
        'title': '新客抽獎：註冊就抽',
        'winnerCount': 15,
        'prizeTitle': '首購加碼',
      };
    }
    // convert
    return {
      'title': '加速成交抽獎：結帳抽獎勵',
      'winnerCount': 6,
      'prizeTitle': '購物金/折扣券',
    };
  }

  // -----------------------------
  // Create drafts
  // -----------------------------
  Future<void> _createDraftPlan() async {
    final seg = _selectedSegment;
    final preview = _preview;
    if (preview == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請先生成預覽再建立草稿')));
      return;
    }

    if (_endAt.isBefore(_startAt)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('結束時間不可早於開始時間')));
      return;
    }

    setState(() => _creating = true);

    try {
      final now = DateTime.now();
      final planRef = _fs.collection('marketing_plans').doc();

      DocumentReference<Map<String, dynamic>>? couponRef;
      DocumentReference<Map<String, dynamic>>? lotteryRef;
      DocumentReference<Map<String, dynamic>>? autoRef;

      final batch = _fs.batch();

      final wantCoupon =
          _bundle == _Bundle.coupon || _bundle == _Bundle.both || _bundle == _Bundle.full;
      final wantLottery =
          _bundle == _Bundle.lottery || _bundle == _Bundle.both || _bundle == _Bundle.full;
      final wantAuto =
          _bundle == _Bundle.auto || _bundle == _Bundle.full;

      // 1) coupon draft
      if (wantCoupon) {
        couponRef = _fs.collection('coupons').doc();
        final s = preview.couponSuggestion;

        batch.set(couponRef, {
          'title': (s['title'] ?? '未命名優惠券').toString(),
          'code': (s['code'] ?? '').toString(),
          'discountType': (s['discountType'] ?? 'amount').toString(),
          'discountValue': _asNum(s['discountValue'] ?? 50),
          'minSpend': _asNum(s['minSpend'] ?? 0),
          'issuedLimit': _asNum(s['issuedLimit'] ?? 999999),

          // 時間
          'startAt': Timestamp.fromDate(_startAt),
          'endAt': Timestamp.fromDate(_endAt),

          // 狀態（草稿先關閉）
          'isActive': false,

          // KPI counters
          'issuedCount': 0,
          'usedCount': 0,
          'clickCount': 0,

          // linkage
          'segmentId': seg?.id,
          'segmentTitle': seg?.title,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'ai_assistant',
          'planId': planRef.id,
        });
      }

      // 2) lottery draft
      if (wantLottery) {
        lotteryRef = _fs.collection('lotteries').doc();
        final s = preview.lotterySuggestion;

        batch.set(lotteryRef, {
          'title': (s['title'] ?? '未命名抽獎').toString(),
          'prizeTitle': (s['prizeTitle'] ?? '').toString(),
          'winnerCount': _asInt(s['winnerCount'] ?? 5),

          'startAt': Timestamp.fromDate(_startAt),
          'endAt': Timestamp.fromDate(_endAt),

          'isActive': false,
          'participants': <dynamic>[],
          'winners': <dynamic>[],

          'segmentId': seg?.id,
          'segmentTitle': seg?.title,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'ai_assistant',
          'planId': planRef.id,
        });
      }

      // 3) auto_campaigns draft
      if (wantAuto) {
        autoRef = _fs.collection('auto_campaigns').doc();
        batch.set(autoRef, {
          'title': '${preview.planTitle}｜自動派發',
          'goal': _goal,
          'channel': _channel,
          'segmentId': seg?.id,
          'segmentTitle': seg?.title,
          'isActive': false,
          'conversionCount': 0,
          'trigger': 'event', // 你可改：cart_abandon / inactivity_7d / purchase_complete 等
          'cooldownHours': 24,
          'startAt': Timestamp.fromDate(_startAt),
          'endAt': Timestamp.fromDate(_endAt),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'ai_assistant',
          'planId': planRef.id,
        });
      }

      // 4) marketing_plans
      batch.set(planRef, {
        'title': preview.planTitle,
        'notes': _notesCtrl.text.trim(),
        'goal': _goal,
        'channel': _channel,
        'bundle': _bundle,

        'segmentId': seg?.id,
        'segmentTitle': seg?.title,
        'segmentSize': seg?.size ?? 0,
        'segmentBaseConversionRatePct': seg?.conversionRate ?? 0.0,

        'startAt': Timestamp.fromDate(_startAt),
        'endAt': Timestamp.fromDate(_endAt),

        'ai': {
          'bullets': preview.bullets,
          'predictedLiftPct': preview.predictedLiftPct,
          'expectedRoiX': preview.expectedRoiX,
          'estimatedConversions': preview.estimatedConversions,
        },

        'assets': {
          'couponId': couponRef?.id,
          'lotteryId': lotteryRef?.id,
          'autoCampaignId': autoRef?.id,
        },

        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'ai_assistant',
        'createdAtLocal': now.toIso8601String(), // 可選：方便 debug
      });

      await batch.commit();

      if (!mounted) return;
      setState(() => _creating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已建立草稿方案：${preview.planTitle}'),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => _openPlanQuickActions(
              planId: planRef.id,
              couponId: couponRef?.id,
              lotteryId: lotteryRef?.id,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('建立草稿失敗：$e')));
    }
  }

  void _openPlanQuickActions({
    required String planId,
    String? couponId,
    String? lotteryId,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '草稿已建立：快速操作',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('在 Firestore 查看 marketing_plans'),
                  subtitle: Text('planId: $planId'),
                ),
                if (couponId != null)
                  ListTile(
                    leading: const Icon(Icons.card_giftcard_outlined),
                    title: const Text('前往優惠券編輯'),
                    subtitle: Text('couponId: $couponId'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/admin/coupons/edit',
                        arguments: {'id': couponId},
                      );
                    },
                  ),
                if (lotteryId != null)
                  ListTile(
                    leading: const Icon(Icons.emoji_events_outlined),
                    title: const Text('前往抽獎編輯'),
                    subtitle: Text('lotteryId: $lotteryId'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/admin/lottery/edit',
                        arguments: {'id': lotteryId},
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('關閉'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePlan(String planId, Map<String, dynamic> assets) async {
    // 安全：只刪 plan 本體；資產是否連動刪除給你決定（這裡提供可選的連動刪除）
    final couponId = (assets['couponId'] ?? '').toString().trim();
    final lotteryId = (assets['lotteryId'] ?? '').toString().trim();
    final autoId = (assets['autoCampaignId'] ?? '').toString().trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除草稿方案？'),
        content: Text(
          '將刪除 marketing_plans/$planId\n\n'
          '是否也一併刪除建立的草稿資源？\n'
          '- coupon: ${couponId.isEmpty ? '無' : couponId}\n'
          '- lottery: ${lotteryId.isEmpty ? '無' : lotteryId}\n'
          '- auto: ${autoId.isEmpty ? '無' : autoId}\n',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final batch = _fs.batch();
      batch.delete(_fs.collection('marketing_plans').doc(planId));
      if (couponId.isNotEmpty) batch.delete(_fs.collection('coupons').doc(couponId));
      if (lotteryId.isNotEmpty) batch.delete(_fs.collection('lotteries').doc(lotteryId));
      if (autoId.isNotEmpty) batch.delete(_fs.collection('auto_campaigns').doc(autoId));
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已刪除草稿方案')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd');
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Campaign Assistant（策略生成器）'),
        actions: [
          IconButton(
            tooltip: '重新讀取分群',
            onPressed: _loadSegments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('1) 方案設定'),
          const SizedBox(height: 8),
          _buildPlanForm(df),

          const SizedBox(height: 16),
          _buildSectionTitle('2) AI 預覽'),
          const SizedBox(height: 8),
          if (preview == null)
            _emptyCard('尚未生成預覽')
          else
            _buildPreviewCard(preview, df),

          const SizedBox(height: 16),
          _buildSectionTitle('3) 建立草稿'),
          const SizedBox(height: 8),
          _buildCreateCard(),

          const SizedBox(height: 16),
          _buildSectionTitle('最近草稿方案'),
          const SizedBox(height: 8),
          _buildRecentPlansList(df),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }

  Widget _emptyCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: const TextStyle(color: Colors.black54)),
      ),
    );
  }

  Widget _buildPlanForm(DateFormat df) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // title
            TextField(
              controller: _planTitleCtrl,
              decoration: const InputDecoration(
                labelText: '方案名稱',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _generatePreview(),
            ),
            const SizedBox(height: 10),

            // segment
            Row(
              children: [
                Expanded(
                  child: _loadingSegments
                      ? const _InlineLoading(label: '讀取分群中…')
                      : DropdownButtonFormField<_SegmentItem>(
                          value: _selectedSegment,
                          decoration: const InputDecoration(
                            labelText: '受眾分群',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: _segments
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('${s.title}（${s.size}）'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedSegment = v);
                            _generatePreview();
                          },
                        ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    // 你已經在 main.dart 接上 /admin/segments/edit
                    Navigator.pushNamed(context, '/admin/segments/edit');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('新增分群'),
                ),
              ],
            ),

            if (_selectedSegment != null &&
                _selectedSegment!.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _selectedSegment!.description,
                style: const TextStyle(color: Colors.black54),
              ),
            ],

            const SizedBox(height: 10),

            // goal / channel / bundle
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _dropdownChip(
                  label: '目標',
                  value: _goal,
                  items: _Goal.items,
                  labelBuilder: _Goal.label,
                  onChanged: (v) {
                    setState(() => _goal = v);
                    _generatePreview();
                  },
                ),
                _dropdownChip(
                  label: '通路',
                  value: _channel,
                  items: _Channel.items,
                  labelBuilder: _Channel.label,
                  onChanged: (v) {
                    setState(() => _channel = v);
                    _generatePreview();
                  },
                ),
                _dropdownChip(
                  label: '組合',
                  value: _bundle,
                  items: _Bundle.items,
                  labelBuilder: _Bundle.label,
                  onChanged: (v) {
                    setState(() => _bundle = v);
                    _generatePreview();
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // dates
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _datePickerTile(
                  label: '開始',
                  value: _startAt,
                  onPick: () async {
                    final v = await _pickDate(_startAt);
                    if (v == null) return;
                    setState(() => _startAt = DateTime(v.year, v.month, v.day));
                    _generatePreview();
                  },
                ),
                _datePickerTile(
                  label: '結束',
                  value: _endAt,
                  onPick: () async {
                    final v = await _pickDate(_endAt);
                    if (v == null) return;
                    setState(() => _endAt = DateTime(v.year, v.month, v.day));
                    _generatePreview();
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: '備註（可選）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownChip({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) labelBuilder,
    required void Function(String) onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(labelBuilder(e))))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
      ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required DateTime value,
    required Future<void> Function() onPick,
  }) {
    final df = DateFormat('yyyy/MM/dd');
    return SizedBox(
      width: 260,
      child: OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.date_range),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text('$label：${df.format(value)}'),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    // ignore: dead_code
  }

  Widget _buildPreviewCard(_AIPreview p, DateFormat df) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.planTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metricChip('分群', p.segmentTitle),
                _metricChip('規模', '${p.segmentSize}'),
                _metricChip('基礎轉換', '${p.baseConversionRatePct.toStringAsFixed(1)}%'),
                _metricChip('預估 Lift', '+${p.predictedLiftPct.toStringAsFixed(1)}%'),
                _metricChip('預估 ROI', '×${p.expectedRoiX.toStringAsFixed(1)}'),
                _metricChip('預估轉換', '${p.estimatedConversions}'),
              ],
            ),
            const SizedBox(height: 10),

            const Text('AI 建議要點', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...p.bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            if (_bundle == _Bundle.coupon ||
                _bundle == _Bundle.both ||
                _bundle == _Bundle.full) ...[
              const Text('優惠券草稿建議', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              _kv('標題', (p.couponSuggestion['title'] ?? '').toString()),
              _kv('代碼', (p.couponSuggestion['code'] ?? '').toString()),
              _kv('折扣', '${p.couponSuggestion['discountType']} ${p.couponSuggestion['discountValue']}'),
              _kv('門檻', '${p.couponSuggestion['minSpend']}'),
            ],

            if (_bundle == _Bundle.lottery ||
                _bundle == _Bundle.both ||
                _bundle == _Bundle.full) ...[
              const SizedBox(height: 10),
              const Text('抽獎草稿建議', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              _kv('標題', (p.lotterySuggestion['title'] ?? '').toString()),
              _kv('獎品', (p.lotterySuggestion['prizeTitle'] ?? '').toString()),
              _kv('名額', (p.lotterySuggestion['winnerCount'] ?? '').toString()),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generatePreview,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('重新生成預覽'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text('$k：$v', style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Widget _buildCreateCard() {
    final preview = _preview;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('一鍵建立草稿（Draft）', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              '會建立：marketing_plans（必定）'
              '${(_bundle == _Bundle.coupon || _bundle == _Bundle.both || _bundle == _Bundle.full) ? ' + coupons' : ''}'
              '${(_bundle == _Bundle.lottery || _bundle == _Bundle.both || _bundle == _Bundle.full) ? ' + lotteries' : ''}'
              '${(_bundle == _Bundle.auto || _bundle == _Bundle.full) ? ' + auto_campaigns' : ''}'
              '；資源預設 isActive=false（避免誤發）。',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_creating || preview == null) ? null : _createDraftPlan,
                    icon: _creating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rocket_launch),
                    label: Text(_creating ? '建立中…' : '建立草稿'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPlansList(DateFormat df) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs
          .collection('marketing_plans')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _InlineLoading(label: '讀取最近方案…');
        }
        if (snap.hasError) {
          return _emptyCard('讀取失敗：${snap.error}');
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _emptyCard('尚無草稿方案（marketing_plans）');

        return Card(
          child: ListView.separated(
            itemCount: docs.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();

              final title = (d['title'] ?? '未命名方案').toString();
              final status = (d['status'] ?? 'draft').toString();
              final segTitle = (d['segmentTitle'] ?? '').toString();
              final assets = (d['assets'] is Map) ? (d['assets'] as Map).cast<String, dynamic>() : <String, dynamic>{};

              final startAt = _toDateTime(d['startAt']);
              final endAt = _toDateTime(d['endAt']);
              final timeText = (startAt != null && endAt != null)
                  ? '${df.format(startAt)} ~ ${df.format(endAt)}'
                  : '';

              final ai = (d['ai'] is Map) ? (d['ai'] as Map).cast<String, dynamic>() : <String, dynamic>{};
              final roi = _asNum(ai['expectedRoiX'] ?? 0).toDouble();
              final lift = _asNum(ai['predictedLiftPct'] ?? 0).toDouble();

              final couponId = (assets['couponId'] ?? '').toString().trim();
              final lotteryId = (assets['lotteryId'] ?? '').toString().trim();

              return ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [
                    if (segTitle.isNotEmpty) '分群：$segTitle',
                    if (timeText.isNotEmpty) '期間：$timeText',
                    '狀態：$status',
                    if (roi > 0) 'ROI×${roi.toStringAsFixed(1)}',
                    if (lift > 0) 'Lift+${lift.toStringAsFixed(1)}%',
                  ].join('  |  '),
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (couponId.isNotEmpty)
                      IconButton(
                        tooltip: '編輯優惠券',
                        icon: const Icon(Icons.card_giftcard_outlined),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/admin/coupons/edit',
                          arguments: {'id': couponId},
                        ),
                      ),
                    if (lotteryId.isNotEmpty)
                      IconButton(
                        tooltip: '編輯抽獎',
                        icon: const Icon(Icons.emoji_events_outlined),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/admin/lottery/edit',
                          arguments: {'id': lotteryId},
                        ),
                      ),
                    IconButton(
                      tooltip: '刪除方案（含草稿資源）',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deletePlan(doc.id, assets),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Helpers / Models
// ------------------------------------------------------------
class _SegmentItem {
  final String id;
  final String title;
  final int size;
  final double conversionRate; // % (0~100)
  final String description;

  const _SegmentItem({
    required this.id,
    required this.title,
    required this.size,
    required this.conversionRate,
    required this.description,
  });
}

class _AIPreview {
  final String planTitle;
  final String segmentTitle;
  final int segmentSize;
  final double baseConversionRatePct;

  final double predictedLiftPct;
  final double expectedRoiX;
  final int estimatedConversions;

  final List<String> bullets;
  final Map<String, dynamic> couponSuggestion;
  final Map<String, dynamic> lotterySuggestion;

  const _AIPreview({
    required this.planTitle,
    required this.segmentTitle,
    required this.segmentSize,
    required this.baseConversionRatePct,
    required this.predictedLiftPct,
    required this.expectedRoiX,
    required this.estimatedConversions,
    required this.bullets,
    required this.couponSuggestion,
    required this.lotterySuggestion,
  });
}

class _InlineLoading extends StatelessWidget {
  final String label;
  const _InlineLoading({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.black54))),
      ],
    );
  }
}

// ------------------------------------------------------------
// Enumerations (string-based to keep simple / compatible)
// ------------------------------------------------------------
class _Goal {
  static const String convert = 'convert';
  static const String reactivate = 'reactivate';
  static const String acquire = 'acquire';
  static const String engage = 'engage';

  static const List<String> items = [convert, reactivate, acquire, engage];

  static String label(String v) {
    switch (v) {
      case convert:
        return '促轉換（下單/使用）';
      case reactivate:
        return '再喚醒（回流）';
      case acquire:
        return '拉新（新客）';
      case engage:
        return '提升互動';
    }
    return v;
  }

  static double boost(String v) {
    switch (v) {
      case convert:
        return 6.0;
      case reactivate:
        return 5.0;
      case acquire:
        return 4.0;
      case engage:
        return 3.0;
    }
    return 0.0;
  }
}

class _Channel {
  static const String push = 'push';
  static const String line = 'line';
  static const String email = 'email';
  static const String sms = 'sms';
  static const String inApp = 'in_app';

  static const List<String> items = [push, line, email, sms, inApp];

  static String label(String v) {
    switch (v) {
      case push:
        return 'Push';
      case line:
        return 'LINE';
      case email:
        return 'Email';
      case sms:
        return 'SMS';
      case inApp:
        return 'In-App';
    }
    return v;
  }

  static double boost(String v) {
    switch (v) {
      case push:
        return 3.0;
      case line:
        return 2.5;
      case email:
        return 2.0;
      case sms:
        return 1.5;
      case inApp:
        return 2.2;
    }
    return 0.0;
  }

  static double roiBias(String v) {
    // 偏向：push/in-app 成本較低；sms 成本較高
    switch (v) {
      case push:
        return 0.35;
      case inApp:
        return 0.30;
      case line:
        return 0.22;
      case email:
        return 0.18;
      case sms:
        return 0.05;
    }
    return 0.0;
  }
}

class _Bundle {
  static const String coupon = 'coupon';
  static const String lottery = 'lottery';
  static const String both = 'both';
  static const String auto = 'auto';
  static const String full = 'full';

  static const List<String> items = [coupon, lottery, both, auto, full];

  static String label(String v) {
    switch (v) {
      case coupon:
        return '優惠券';
      case lottery:
        return '抽獎';
      case both:
        return '優惠券 + 抽獎';
      case auto:
        return '自動派發';
      case full:
        return '全功能（券+抽獎+自動派發）';
    }
    return v;
  }

  static double boost(String v) {
    switch (v) {
      case coupon:
        return 2.5;
      case lottery:
        return 2.0;
      case both:
        return 3.5;
      case auto:
        return 3.0;
      case full:
        return 4.0;
    }
    return 0.0;
  }

  static double costPenalty(String v) {
    // 組合越大，成本/風險越高，ROI 略扣
    switch (v) {
      case coupon:
        return 0.10;
      case lottery:
        return 0.12;
      case both:
        return 0.18;
      case auto:
        return 0.14;
      case full:
        return 0.22;
    }
    return 0.0;
  }
}

// ------------------------------------------------------------
// Value helpers (safe conversions)
// ------------------------------------------------------------
int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

num _asNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

/// 把 conversionRate 轉成「百分比」(0~100)
double _normalizeRate(dynamic v) {
  if (v == null) return 0.8; // default %
  final n = _asNum(v).toDouble();
  if (n <= 1.0) {
    // 常見：0~1
    return (n * 100).clamp(0, 100).toDouble();
  }
  return n.clamp(0, 100).toDouble();
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}
