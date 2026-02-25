// lib/pages/ai_support_page.dart
//
// ✅ AiSupportPage（最終完整版｜已修正 unused_element：移除未使用的 _s）
// ------------------------------------------------------------
// - 不依賴外部套件（只用 Flutter Material）
// - 提供簡易 AI 客服對話（規則/關鍵字回覆）
// - 快捷問題 Chips：付款 / 訂單 / 物流 / 退換貨 / 保固 / 優惠券 / 點數 / SOS
// - 支援清除對話、複製最後回覆
//
// 若你之後要串真正的 AI（OpenAI/自建 API），只要把 _replyFor(...) 換成你的 API 呼叫即可。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AiSupportPage extends StatefulWidget {
  const AiSupportPage({super.key});

  @override
  State<AiSupportPage> createState() => _AiSupportPageState();
}

class _AiSupportPageState extends State<AiSupportPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_ChatMsg> _msgs = <_ChatMsg>[
    const _ChatMsg(
      role: _Role.assistant,
      text:
          '嗨～我是 Osmile AI 客服。\n你可以直接描述問題（例如：付款失敗、找不到優惠券、如何查訂單、保固怎麼申請）。\n我也提供下方快捷問題。',
      ts: null,
    ),
  ];

  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _msgs.add(_ChatMsg(role: _Role.user, text: text, ts: DateTime.now()));
      _inputCtrl.clear();
    });
    _scrollToBottomSoon();

    // 模擬 AI 思考時間
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final reply = _replyFor(text);

    setState(() {
      _msgs.add(
        _ChatMsg(role: _Role.assistant, text: reply, ts: DateTime.now()),
      );
      _sending = false;
    });
    _scrollToBottomSoon();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearChat() {
    setState(() {
      _msgs
        ..clear()
        ..add(
          const _ChatMsg(
            role: _Role.assistant,
            text: '已清除對話。你可以重新描述問題，或點選快捷問題。',
            ts: null,
          ),
        );
    });
  }

  Future<void> _copyLastAssistant() async {
    final last = _msgs.lastWhere(
      (m) => m.role == _Role.assistant,
      orElse: () => const _ChatMsg(role: _Role.assistant, text: '', ts: null),
    );
    if (last.text.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: last.text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已複製最後一則回覆')));
  }

  @override
  Widget build(BuildContext context) {
    final quick = <String>[
      '付款/交易問題',
      '查訂單',
      '物流配送',
      '退換貨/退款',
      '保固/維修',
      '優惠券怎麼用',
      '點數怎麼拿',
      'SOS 求助',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 客服支援'),
        actions: [
          IconButton(
            tooltip: '複製最後回覆',
            onPressed: _copyLastAssistant,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: '清除對話',
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          // 快捷問題
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) => ActionChip(
                label: Text(quick[i]),
                onPressed: _sending ? null : () => _send(quick[i]),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: quick.length,
            ),
          ),
          const Divider(height: 1),

          // 訊息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_sending && index == _msgs.length) {
                  return const _TypingBubble();
                }
                final m = _msgs[index];
                return _ChatBubble(msg: m);
              },
            ),
          ),

          const Divider(height: 1),

          // 輸入列
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '輸入問題…（例如：優惠券找不到）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    label: const Text('送出'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // ✅ 規則式客服回覆（可替換成真正 AI / API）
  // -----------------------------
  String _replyFor(String input) {
    final t = input.toLowerCase();

    bool hasAny(List<String> keys) =>
        keys.any((k) => t.contains(k.toLowerCase()));

    // 支付/交易
    if (hasAny([
      '付款',
      '交易',
      '刷卡',
      'linepay',
      '信用卡',
      '支付',
      '失敗',
      '扣款',
      '付款失敗',
    ])) {
      return [
        '如果是付款/交易問題，你可以先照這幾步排查：',
        '1) 確認網路穩定，重新進入結帳頁再嘗試一次。',
        '2) 若是第三方支付（如 LINE Pay/信用卡），請確認付款頁面有完成回跳到 App。',
        '3) 到「我的訂單」查看該筆是否顯示：已付款 / 待付款。',
        '4) 若已扣款但訂單仍待付款：先不要重複扣款，可截圖訂單編號與扣款時間，提供客服協助對帳。',
        '',
        '你可以回覆我：使用哪種付款方式 + 目前訂單狀態（待付款/已付款）+ 是否已扣款，我再幫你對應下一步。',
      ].join('\n');
    }

    // 訂單
    if (hasAny(['訂單', '查訂單', '我的訂單', '訂單編號', '出貨', '取消訂單'])) {
      return [
        '查訂單路徑通常是：**我的 → 訂單 / 購買紀錄**。',
        '',
        '常見狀態說明：',
        '- 待付款：尚未完成支付（可重新付款或取消）',
        '- 已付款：等待出貨處理',
        '- 已出貨：可在訂單內看物流單號',
        '- 已完成：收貨完成/超過確認期限',
        '',
        '如果你說明「訂單狀態」跟「想處理的需求（取消/改地址/加購）」我可以給你最短流程。',
      ].join('\n');
    }

    // 物流
    if (hasAny(['物流', '配送', '到貨', '運送', '宅配', '超商', '單號', '運費', '地址'])) {
      return [
        '物流/配送建議你先確認：',
        '1) 訂單狀態是否已出貨（已出貨才會有單號）',
        '2) 進入訂單詳情看「物流單號/配送方式」',
        '3) 若需要更改地址：通常要在「未出貨」前處理（已出貨就只能攔截/改配，依物流而定）',
        '',
        '你可以貼：訂單狀態 + 是否已看到單號 + 配送方式（宅配/超商），我再幫你下一步。',
      ].join('\n');
    }

    // 退換貨/退款
    if (hasAny(['退貨', '換貨', '退款', '退費', '取消', '瑕疵', '破損'])) {
      return [
        '退換貨/退款常見流程：',
        '1) 到「我的訂單」找到該筆 → 申請退/換/退款（若有此按鈕）',
        '2) 上傳照片（外觀/瑕疵/包裝）與問題描述',
        '3) 等待審核後依指示寄回或換貨',
        '',
        '建議你提供：訂單編號 + 收到日期 + 問題類型（瑕疵/不符/不想要）+ 是否已拆封使用，流程會更精準。',
      ].join('\n');
    }

    // 保固/維修
    if (hasAny(['保固', '維修', '故障', '壞掉', '無法充電', '螢幕', '電池', '重置'])) {
      return [
        '保固/維修建議先做快速排查：',
        '1) 充電 30 分鐘以上（更換充電頭/線/插座測試）',
        '2) 嘗試重啟/重置（若有教學頁面可依指示）',
        '3) 若仍異常：準備「訂單編號/購買日期/序號（若有）」+ 問題描述與照片/影片',
        '',
        '我可以幫你整理送修資料清單，你回覆我：型號 + 問題現象 + 是否可開機。',
      ].join('\n');
    }

    // 優惠券
    if (hasAny(['優惠券', '折扣碼', 'coupon', '代碼', '折抵', '無法使用', '找不到優惠券'])) {
      return [
        '優惠券常見無法使用原因：',
        '1) 未達門檻（滿額/指定品類/指定商品）',
        '2) 已過期或尚未到可用時間',
        '3) 限定新會員/首購/特定帳號',
        '4) 同一張券已使用或與其他優惠不可併用',
        '',
        '你可以提供：優惠券名稱/代碼 + 你購物車內容與金額 + 系統提示文字，我可以幫你判斷是哪一種限制。',
      ].join('\n');
    }

    // 點數
    if (hasAny(['點數', '積分', '任務', '簽到', '回饋', 'points'])) {
      return [
        '點數通常可透過：簽到/任務/活動/消費回饋取得（以你們 App 設計為準）。',
        '建議你先看：**我的 → 點數/任務中心**。',
        '',
        '常見問題：',
        '- 點數沒入帳：可能有延遲或需完成條件（如完成訂單）',
        '- 無法折抵：可能有限制（最低金額、最高折抵比例）',
        '',
        '你回覆我：你是「拿點數」還是「用點數折抵」？我給你對應路徑。',
      ].join('\n');
    }

    // SOS
    if (hasAny(['sos', '求救', '緊急', '陌生人', '手錶', '按鍵', '警報', '定位'])) {
      return [
        'SOS 求助功能一般會包含：長按/連按按鍵 → 發送求救通知 → 家長端/緊急聯絡人收到提醒與定位。',
        '',
        '你可以先確認：',
        '1) 裝置是否已綁定（手錶 ↔ 帳號）',
        '2) 家長端是否已設定「緊急聯絡人/通知權限」',
        '3) App 是否允許定位權限（前景/背景）與通知權限',
        '',
        '如果你說明：手機型號（iOS/Android）+ 是否收得到通知 + 是否有定位，我可以幫你定位是哪個環節卡住。',
      ].join('\n');
    }

    // fallback
    return [
      '我收到你的問題了。為了更精準幫你排查，你可以補充：',
      '- 你在哪個頁面遇到問題（商品/購物車/結帳/訂單/我的）？',
      '- 系統顯示的提示文字是什麼？（可貼上或截圖文字）',
      '- 你使用的裝置（iOS/Android）？',
      '',
      '你也可以直接點上方快捷問題，我會給你對應流程。',
    ].join('\n');
  }
}

enum _Role { user, assistant }

class _ChatMsg {
  const _ChatMsg({required this.role, required this.text, required this.ts});

  final _Role role;
  final String text;
  final DateTime? ts;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.msg});

  final _ChatMsg msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == _Role.user;

    final bg = isUser ? Colors.blue.shade600 : Colors.grey.shade200;
    final fg = isUser ? Colors.white : Colors.black87;

    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isUser ? 14 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 14),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: DecoratedBox(
              decoration: BoxDecoration(color: bg, borderRadius: radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(color: fg, height: 1.25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                SizedBox(width: 10),
                Text('回覆中…'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
