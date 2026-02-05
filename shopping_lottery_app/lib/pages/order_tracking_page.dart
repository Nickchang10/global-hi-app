import 'package:flutter/material.dart';
import 'dart:async';

/// 🚚 訂單追蹤頁（模擬出貨進度）
class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  final String trackingCode;

  const OrderTrackingPage({
    super.key,
    required this.orderId,
    required this.trackingCode,
  });

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  int progress = 0;
  Timer? timer;

  final List<String> statusSteps = [
    "已成立訂單",
    "倉庫備貨中",
    "物流已取件",
    "配送中",
    "已送達",
  ];

  @override
  void initState() {
    super.initState();

    /// 🔹 模擬物流進度
    timer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (progress < statusSteps.length - 1) {
        setState(() => progress++);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("訂單追蹤"),
        backgroundColor: const Color(0xFF007BFF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _orderInfoCard(),
            const SizedBox(height: 24),
            const Text(
              "物流進度",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF007BFF),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: statusSteps.length,
                itemBuilder: (context, index) {
                  final active = index <= progress;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF007BFF)
                                  : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: active
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          if (index != statusSteps.length - 1)
                            Container(
                              width: 3,
                              height: 40,
                              color: active
                                  ? const Color(0xFF007BFF)
                                  : Colors.grey[300],
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 6),
                          child: Text(
                            statusSteps[index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: active
                                  ? const Color(0xFF007BFF)
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                progress == statusSteps.length - 1
                    ? "✅ 已送達目的地"
                    : "⏳ 運送中，請稍候...",
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("訂單編號：${widget.orderId}",
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text("物流單號：${widget.trackingCode}",
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              "預估抵達：${DateTime.now().add(const Duration(days: 2)).toString().substring(0, 10)}",
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
