import 'package:flutter/material.dart';
import 'dart:async';
import '../services/notification_service.dart';

class OrderTrackingLivePage extends StatefulWidget {
  final String orderId;

  const OrderTrackingLivePage({super.key, required this.orderId});

  @override
  State<OrderTrackingLivePage> createState() => _OrderTrackingLivePageState();
}

class _OrderTrackingLivePageState extends State<OrderTrackingLivePage> {
  int _stepIndex = 0;
  double _truckX = 0.1;
  double _truckY = 0.8;
  Timer? _timer;

  final List<Map<String, dynamic>> _steps = [
    {"title": "已出貨", "desc": "包裹已交由物流公司處理"},
    {"title": "配送中", "desc": "物流人員正前往送達中"},
    {"title": "已送達", "desc": "包裹已送達目的地"},
  ];

  final _notify = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  void _startSimulation() {
    _timer?.cancel();
    _stepIndex = 0;
    _truckX = 0.1;
    _truckY = 0.8;

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_stepIndex < _steps.length - 1) {
        setState(() {
          _stepIndex++;
          _truckX += 0.3;
          _truckY -= 0.2;
        });

        // 🔔 每次物流階段改變時，推播通知
        _notify.addNotification(
          title: "🚚 ${_steps[_stepIndex]["title"]}",
          message: _steps[_stepIndex]["desc"],
          icon: Icons.local_shipping_outlined,
          orderId: widget.orderId,
          context: context,
          showOverlay: true,
        );
      } else {
        // 最後一階段 → 已送達
        _notify.addNotification(
          title: "✅ 包裹已送達",
          message: "您的訂單 #${widget.orderId} 已完成配送，感謝支持！",
          icon: Icons.check_circle_outline,
          orderId: widget.orderId,
          context: context,
          showOverlay: true,
        );
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        title: Text("即時物流追蹤 #${widget.orderId}"),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade100,
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CustomPaint(painter: _MapRoutePainter()),
            ),
          ),

          // 🚚 模擬配送車
          AnimatedPositioned(
            duration: const Duration(seconds: 2),
            left: MediaQuery.of(context).size.width * _truckX,
            top: MediaQuery.of(context).size.height * _truckY - 100,
            child: const Icon(Icons.local_shipping,
                size: 48, color: Color(0xFF007BFF)),
          ),

          // 狀態資訊卡
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _steps[_stepIndex]["title"],
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007BFF)),
                  ),
                  const SizedBox(height: 6),
                  Text(_steps[_stepIndex]["desc"],
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (_stepIndex + 1) / _steps.length,
                    backgroundColor: Colors.grey.shade300,
                    color: const Color(0xFF007BFF),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "更新時間：${TimeOfDay.now().format(context)}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startSimulation,
        icon: const Icon(Icons.play_arrow),
        label: const Text("重新模擬物流"),
        backgroundColor: const Color(0xFF007BFF),
      ),
    );
  }
}

/// 🗺️ 模擬地圖路線
class _MapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade400
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.3, size.height * 0.5,
        size.width * 0.5, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.7,
        size.width * 0.9, size.height * 0.2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
