// lib/widgets/google_map_stub.dart
import 'package:flutter/material.dart';
import '../services/tracking_service.dart';

class PlatformMapView extends StatelessWidget {
  final TrackingPoint? local;
  final TrackingPoint? remote;
  final List<TrackingPoint> history;

  const PlatformMapView({
    super.key,
    required this.local,
    required this.remote,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPainter(history),
      child: const Center(
        child: Text('模擬地圖（Web 測試模式）'),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<TrackingPoint> list;
  _MapPainter(this.list);

  @override
  void paint(Canvas canvas, Size size) {
    if (list.isEmpty) return;
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    final lats = list.map((e) => e.lat).toList();
    final lngs = list.map((e) => e.lng).toList();

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    double toX(double lng) =>
        (lng - minLng) / (maxLng - minLng + 1e-9) * size.width;
    double toY(double lat) =>
        size.height - (lat - minLat) / (maxLat - minLat + 1e-9) * size.height;

    for (int i = 0; i < list.length; i++) {
      final p = list[i];
      final x = toX(p.lng);
      final y = toY(p.lat);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
    final last = list.last;
    canvas.drawCircle(
      Offset(toX(last.lng), toY(last.lat)),
      6,
      Paint()..color = Colors.red,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.list.length != list.length;
}
