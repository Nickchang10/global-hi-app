import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translator/translator.dart';
import '../services/language_service.dart';
import '../services/translation_service.dart';
import '../services/firestore_mock_service.dart';
import '../services/notification_service.dart';

/// 🧠 AI 雲端情境客服中心（Context Cloud Center）
///
/// 核心：
/// - 多角色自動分配
/// - 意圖偵測 + 分類
/// - 智慧回覆建議
/// - 雲端同步客服任務
class AiContextCenterPage extends StatefulWidget {
  const AiContextCenterPage({super.key});

  @override
  State<AiContextCenterPage> createState() => _AiContextCenterPageState();
}

class _AiContextCenterPageState extends State<AiContextCenterPage> {
  final TextEditingController _controller = TextEditingController();
  final translator = GoogleTranslator();
  final mock = FirestoreMockService.instance;
  final notifier = NotificationService.instance;
  bool _isProcessing = false;
  List<Map<String, String>> _messages = [];

  @override
  Widget build(BuildContext context) {
    final tr = Provider.of<LanguageService>(context).tr;
    return Scaffold(
      appBar: AppBar(
        title: Text("AI 雲端客服中心"),
        backgroundColor: const Color(0xFF007BFF),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: () => Provider.of<LanguageService>(context, listen: false).cycleLanguage(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final user = msg["from"] == "user";
                return Align(
                  alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: user ? Colors.blueAccent : Colors.grey[200],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: TextStyle(
                        color: user ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          _buildInputBar(tr),
        ],
      ),
    );
  }

  Widget _buildInputBar(String Function(String) tr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: tr("type_your_message"),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF007BFF)),
            onPressed: _isProcessing ? null : _handleSend,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.insert(0, {"from": "user", "text": text});
      _controller.clear();
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    await _processContext(text);
  }

  /// 🧠 AI 核心流程：語意分析 + 客服分類 + 任務建立
  Future<void> _processContext(String text) async {
    final trText = await translator.translate(text, to: "en");
    final intent = _detectIntent(trText.text);
    final persona = _assignPersona(intent);
    final replies = _generateReplyOptions(intent, persona);

    mock.addAiMessage({
      "from": persona,
      "intent": intent,
      "text": replies.first,
      "time": DateTime.now(),
    });

    notifier.addNotification(
      title: "AI 任務：$intent",
      message: replies.first,
      icon: Icons.support_agent,
    );

    setState(() {
      _isProcessing = false;
      _messages.insert(0, {"from": persona, "text": replies.first});
    });

    // 🔄 模擬建立雲任務
    mock.addSupportTicket({
      "id": DateTime.now().millisecondsSinceEpoch,
      "intent": intent,
      "assignedTo": persona,
      "status": "pending",
      "createdAt": DateTime.now(),
    });
  }

  /// 🎯 AI 意圖分析（模擬版）
  String _detectIntent(String text) {
    final lower = text.toLowerCase();
    if (lower.contains("shipping") || lower.contains("delivery") || lower.contains("出貨")) return "物流問題";
    if (lower.contains("refund") || lower.contains("退貨")) return "退貨申請";
    if (lower.contains("discount") || lower.contains("coupon") || lower.contains("優惠")) return "優惠活動";
    if (lower.contains("payment") || lower.contains("credit")) return "付款問題";
    if (lower.contains("account") || lower.contains("login")) return "帳號登入";
    return "一般諮詢";
  }

  /// 👩‍💼 自動指派客服人格
  String _assignPersona(String intent) {
    switch (intent) {
      case "物流問題":
        return "🚚 物流客服 Jack";
      case "退貨申請":
        return "📦 售後客服 May";
      case "優惠活動":
        return "🎁 行銷客服 Emma";
      case "付款問題":
        return "💳 金流客服 Leo";
      case "帳號登入":
        return "🔐 技術客服 Kai";
      default:
        return "💬 一般客服 Lisa";
    }
  }

  /// 💬 產生回覆建議
  List<String> _generateReplyOptions(String intent, String persona) {
    switch (intent) {
      case "物流問題":
        return [
          "您的包裹已出貨，預計 2 天內抵達。",
          "我們正在為您查詢物流狀態，請稍候。",
          "📦 若需加急，請提供訂單號。",
        ];
      case "退貨申請":
        return [
          "已收到退貨申請，將於 3 個工作天內審核。",
          "請將商品包裝完整寄回指定地址。",
          "退款將於完成驗收後 5 天內退回。",
        ];
      case "優惠活動":
        return [
          "🎉 本週全館 85 折，登入會員可享額外優惠。",
          "請至「積分商城」查看可兌換的折價券。",
          "本次活動有效期至月底喔～",
        ];
      case "付款問題":
        return [
          "請確認信用卡是否開啟網路交易功能。",
          "我們的金流目前維護中，請稍後再試。",
          "若重複扣款，請提供交易編號。",
        ];
      case "帳號登入":
        return [
          "請確認輸入的帳號與密碼正確。",
          "若忘記密碼，可使用「重設密碼」功能。",
          "如仍無法登入，將協助重置帳號權限。",
        ];
      default:
        return [
          "感謝您的來信，我們將儘快回覆。",
          "您的問題已收到，正在分派客服。",
          "若有急件，可撥打服務專線。",
        ];
    }
  }
}
