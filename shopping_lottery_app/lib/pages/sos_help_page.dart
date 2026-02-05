import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SosHelpPage extends StatelessWidget {
  const SosHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        title: Text(
          "SOS 求助教學",
          style: GoogleFonts.notoSansTc(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 頂部說明卡
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sos,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "遇到危險、迷路或不安心的狀況時，小朋友只要長按手錶右側按鍵，"
                    "就能啟動 SOS 求助，家長手機會立即收到通知。",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 孩子端操作
          const Text(
            "孩子端操作步驟",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _buildStepCard(
            step: "1",
            title: "遇到覺得不安全的情況",
            desc: "例如：迷路、被陌生人跟隨、身體不舒服、找不到家長…等。",
          ),
          _buildStepCard(
            step: "2",
            title: "長按手錶右側按鍵 3 秒",
            desc: "螢幕會顯示「SOS 求助中」或紅色警示圖示，小朋友只要記得「按著不放」。",
          ),
          _buildStepCard(
            step: "3",
            title: "手錶自動發送求救訊號",
            desc: "系統會自動傳送定位與 SOS 訊息到家長 App 或簡訊（依實際方案而定）。",
          ),

          const SizedBox(height: 20),

          // 家長端收到通知流程
          const Text(
            "家長端收到通知後",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _buildParentStep(
            icon: Icons.notifications_active_outlined,
            title: "收到 SOS 推播 / 簡訊",
            desc: "家長手機會跳出「SOS 求助」通知，提醒立即查看。",
          ),
          _buildParentStep(
            icon: Icons.location_on_outlined,
            title: "點開查看孩子位置",
            desc: "開啟 Osmile App（或後台系統），可查看孩子目前定位與歷史軌跡。",
          ),
          _buildParentStep(
            icon: Icons.call_outlined,
            title: "聯絡孩子或現場人員",
            desc: "視情況立即撥打電話給孩子、老師、或就近聯絡展場服務台。",
          ),

          const SizedBox(height: 20),

          // 情境示意（國小生遇到陌生人）
          const Text(
            "情境示意：國小生遇到陌生人",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              "小朋友放學回家途中，有陌生大人主動搭話並要帶他走。\n\n"
              "這時候，小朋友可以：\n"
              "• 馬上往人多、明亮的地方移動\n"
              "• 同時長按手錶右側按鍵 3 秒，啟動 SOS\n"
              "• 家長會在手機上收到求救通知與定位\n\n"
              "這個流程可以教給小朋友：只要「覺得不對勁」，就可以啟動 SOS，"
              "不用等到真的發生事情才求救。",
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),

          const SizedBox(height: 20),

          // 常見問答
          const Text(
            "常見問答 Q&A（示意）",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _buildQaItem(
            question: "Q：小朋友會不會誤觸 SOS？",
            answer:
                "A：可以設計為「長按 3 秒」才觸發，或在 App 端提供「誤觸回報」，"
                "實際產品可依需求調整。",
          ),
          _buildQaItem(
            question: "Q：求救訊號會傳到哪裡？",
            answer:
                "A：可設定傳送到主要家長手機 App、簡訊，或多位家屬裝置（依實際方案決定）。",
          ),
          _buildQaItem(
            question: "Q：展場 Demo 跟正式版有什麼差別？",
            answer:
                "A：目前畫面為示意教學，實際 SOS 流程會與後端伺服器、簡訊 / 推播服務串接。",
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              "本頁為 SOS 教學示意，實際功能以正式產品為準。",
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 孩子端 Step 卡片
  static Widget _buildStepCard({
    required String step,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.redAccent.withOpacity(0.12),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 家長端 Step 卡片
  static Widget _buildParentStep({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.redAccent.withOpacity(0.08),
            child: Icon(icon, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Q&A 卡片
  static Widget _buildQaItem({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
