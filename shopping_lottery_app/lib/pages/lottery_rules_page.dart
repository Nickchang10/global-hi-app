import 'package:flutter/material.dart';

class LotteryRulesPage extends StatelessWidget {
  const LotteryRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
    final bodyStyle = const TextStyle(
      fontSize: 13,
      height: 1.4,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("活動說明"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: "一、活動期間",
            child: Text(
              "本抽獎活動期間以展場公告或 App 公告為主，如有變更將另行通知。",
              style: bodyStyle,
            ),
          ),
          _SectionCard(
            title: "二、參加資格",
            child: Text(
              "1. 於展場或線上完成基本資料填寫之訪客或會員。\n"
              "2. 每位帳號需為本人使用，不得轉讓或共用。\n"
              "3. 若有不正當操作，主辦單位保留取消資格之權利。",
              style: bodyStyle,
            ),
          ),
          _SectionCard(
            title: "三、抽獎機制",
            child: Text(
              "1. 每次抽獎需扣除 50 積分。\n"
              "2. 抽中「XX 積分」獎項時，系統將自動將對應積分加回帳號。\n"
              "3. 抽中「再抽一次」不另回補積分，但可視活動規則給予額外機會。\n"
              "4. 獎項內容與中獎機率由主辦單位統一規劃，並保留調整權利。",
              style: bodyStyle,
            ),
          ),
          _SectionCard(
            title: "四、獎項說明",
            child: Text(
              "1. 「積分獎」可用於後續折抵、兌換禮品或參加其他活動，實際用途依現場或 App 公告為準。\n"
              "2. 「折價券」類獎項須於指定期限內使用，逾期視同放棄。\n"
              "3. 「實體贈品」請依現場工作人員指示領取或登記寄送。",
              style: bodyStyle,
            ),
          ),
          _SectionCard(
            title: "五、注意事項",
            child: Text(
              "1. 抽獎一經操作，恕不接受取消或更改。\n"
              "2. 若因網路、系統異常導致重複扣點或顯示錯誤，請聯繫客服協助處理。\n"
              "3. 主辦單位保留隨時修改、變更、終止本活動之權利，修改內容將公告於現場或 App 中。",
              style: bodyStyle,
            ),
          ),
          _SectionCard(
            title: "六、個資與隱私",
            child: Text(
              "1. 您所提供之個人資料，僅供本活動聯絡、中獎通知及服務優化使用。\n"
              "2. 未經您的同意，不會任意揭露於第三方，法律或主管機關要求除外。\n"
              "3. 相關隱私權內容請參考「隱私權政策」。",
              style: bodyStyle,
            ),
          ),
          _SectionCard(
            title: "七、客服聯絡方式",
            child: Text(
              "如對本活動有任何疑問，歡迎透過下列方式聯繫：\n"
              "• 官方 Line 客服\n"
              "• 客服電話：由現場工作人員提供\n"
              "• 線上表單或電子郵件：請見官網或 App 內說明",
              style: bodyStyle,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              "Osmile 保留本活動最終解釋權。",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
