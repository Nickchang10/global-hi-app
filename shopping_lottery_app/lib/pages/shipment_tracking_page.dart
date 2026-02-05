import 'package:flutter/material.dart';
import 'dart:async';
import '../services/notification_service.dart';

class ShipmentTrackingPage extends StatefulWidget {
  final String orderId;
  final DateTime orderDate;

  const ShipmentTrackingPage({
    super.key,
    required this.orderId,
    required this.orderDate,
  });

  @override
  State<ShipmentTrackingPage> createState() => _ShipmentTrackingPageState();
}

class _ShipmentTrackingPageState extends State<ShipmentTrackingPage> {
  final List<String> _steps = ["揀貨中", "配送中", "已送達"];
  int _currentStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 🕒 模擬物流進度更新（每 30 秒進一步）
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
        // 🔔 發送物流通知
        NotificationService.instance.addNotification(
          title: "物流進度更新 📦",
          message: "您的訂單 #${widget.orderId} 狀態已更新為「${_steps[_currentStep]}」。",
          type: "shipping",
          icon: Icons.local_shipping,
        );
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get estimatedDelivery {
    final date = widget.orderDate.add(const Duration(days: 2));
    return "${date.year}/${date.month}/${date.day}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("物流追蹤")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("訂單編號：${widget.orderId}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("預計送達時間：$estimatedDelivery"),
            const SizedBox(height: 24),
            const Text(
              "物流進度",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stepper(
                currentStep: _currentStep,
                steps: _steps
                    .map((label) => Step(
                          title: Text(label),
                          content: Text(_getDescription(label)),
                          isActive: _steps.indexOf(label) <= _currentStep,
                          state: _steps.indexOf(label) <= _currentStep
                              ? StepState.complete
                              : StepState.indexed,
                        ))
                    .toList(),
                controlsBuilder: (context, details) => const SizedBox(),
              ),
            ),
            if (_currentStep == _steps.length - 1)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "✅ 已送達，感謝您的購買！",
                  style: TextStyle(
                      color: Color(0xFF007BFF),
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDescription(String label) {
    switch (label) {
      case "揀貨中":
        return "倉庫正在準備您的商品。";
      case "配送中":
        return "包裹正在前往您的地址途中。";
      case "已送達":
        return "商品已順利送達。";
      default:
        return "";
    }
  }
}
