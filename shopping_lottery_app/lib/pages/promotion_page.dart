import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class PromotionPage extends StatefulWidget {
  const PromotionPage({super.key});

  @override
  State<PromotionPage> createState() => _PromotionPageState();
}

class _PromotionPageState extends State<PromotionPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  bool _loading = true;
  bool _expired = false;
  DateTime? _endTime;
  Timer? _timer;

  String _title = "AI 行銷中心";
  String? _subtitle;

  List<Map<String, dynamic>> _recommended = [];

  @override
  void initState() {
    super.initState();
    _loadCampaignFromCloud();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 從 Firestore 讀取活動設定：
  /// promotions/global_campaign
  Future<void> _loadCampaignFromCloud() async {
    setState(() {
      _loading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('promotions')
          .doc('global_campaign')
          .get();

      if (!doc.exists) {
        setState(() {
          _loading = false;
          _expired = true;
          _recommended = [];
          _subtitle = "目前沒有進行中的活動，敬請期待。";
        });
        return;
      }

      final data = doc.data() ?? {};
      final bool isActive = data['isActive'] == true;

      _title = data['title'] ?? "AI 行銷中心";
      _subtitle = data['subtitle'];

      final ts = data['endTime'];
      if (ts is Timestamp) {
        _endTime = ts.toDate();
      }

      // 讀取推薦商品清單（陣列）
      final itemsRaw = data['items'];
      if (itemsRaw is List) {
        _recommended =
            itemsRaw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _recommended = [];
      }

      final now = DateTime.now();
      final bool timeExpired =
          _endTime != null && now.isAfter(_endTime!);

      setState(() {
        _loading = false;
        _expired = !isActive || timeExpired;
      });

      // 活動還有效才啟動倒數
      if (!_expired && _endTime != null) {
        _startCountdown();
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _expired = true;
        _subtitle = "讀取活動資料失敗，請稍後再試。";
      });
    }
  }

  /// 啟動倒數計時
  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_endTime == null || now.isAfter(_endTime!)) {
        setState(() {
          _expired = true;
        });
        timer.cancel();
      } else {
        setState(() {});
      }
    });
  }

  /// 加入購物車（活動結束時自動禁用）
  Future<void> _addToCart(Map<String, dynamic> item) async {
    if (_expired) return;

    final data = {
      "name": item["name"],
      "price": item["price"],
      "quantity": 1,
      "category": item["category"],
      "time": DateTime.now(),
    };

    await FirestoreService.addCartItem(uid, data);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${item["name"]} 已加入購物車 🛒"),
          backgroundColor: const Color(0xFF007BFF),
        ),
      );
    }
  }

  /// 計算剩餘時間文字
  String _remainingText() {
    if (_endTime == null) {
      return "本次活動時間尚未設定";
    }
    if (_expired) {
      return "本次限時優惠已結束";
    }

    final now = DateTime.now();
    Duration diff = _endTime!.difference(now);
    if (diff.isNegative) diff = Duration.zero;

    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(diff.inHours);
    final m = two(diff.inMinutes.remainder(60));
    final s = two(diff.inSeconds.remainder(60));

    return "本次限時優惠倒數：$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "重新載入活動",
            onPressed: _loadCampaignFromCloud,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCountdownHeader(),
                if (_subtitle != null) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      _subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Expanded(
                  child: _recommended.isEmpty
                      ? const Center(
                          child: Text(
                            "目前沒有推薦商品。",
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _recommended.length,
                          itemBuilder: (context, index) {
                            final item = _recommended[index];
                            return _buildPromoCard(item);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// 頂部倒數顯示區
  Widget _buildCountdownHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _expired ? Colors.grey.shade300 : const Color(0xFF007BFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _expired ? Icons.timer_off_outlined : Icons.timer_outlined,
            color: _expired ? Colors.black54 : Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _remainingText(),
              style: TextStyle(
                color: _expired ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 單張推薦卡片（會依 _expired 狀態變化 UI）
  Widget _buildPromoCard(Map<String, dynamic> item) {
    final isDisabled = _expired;

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (item["image"] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item["image"],
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_not_supported_outlined,
                    color: Color(0xFF007BFF)),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["name"] ?? "未命名商品",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item["discount"] != null)
                    Text(
                      "優惠：${item["discount"]}",
                      style: const TextStyle(
                          color: Color(0xFF007BFF), fontSize: 13),
                    ),
                  const SizedBox(height: 4),
                  if (item["price"] != null)
                    Text(
                      "NT\$${item["price"]}",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item["tag"] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007BFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item["tag"],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: isDisabled ? null : () => _addToCart(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007BFF),
                          disabledBackgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 10),
                        ),
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: Text(
                          isDisabled ? "活動已結束" : "加入購物車",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
