// lib/pages/tracking_map_page.dart
// ======================================================
// ✅ TrackingMapPage（最終穩定版｜Chrome 可編譯）
// ------------------------------------------------------
// - 不使用 google_maps_flutter（避免 Web/套件缺失編譯失敗）
// - 地圖區塊改用 CustomPaint 畫軌跡 + 本機/遠端點位
// - 保留：lastLocal / lastRemote / history 顯示
// - 保留：Google Maps 外開
// - 保留：SOS 快捷按鈕（用 dynamic 呼叫，避免方法簽名不一致造成編譯錯）
//
// ✅ 修正重點：
// - use_build_context_synchronously：initState 改用 addPostFrameCallback + mounted 檢查
// - withOpacity deprecated：全面改用 withValues(alpha: ...)
// - async gaps 後使用 context：補 mounted 檢查
// - ✅ prefer_const_constructors：Legend Row children 全 const
// ======================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/tracking_service.dart';
import '../services/sos_service.dart';
import '../services/notification_service.dart';

class TrackingMapPage extends StatefulWidget {
  const TrackingMapPage({super.key});

  @override
  State<TrackingMapPage> createState() => _TrackingMapPageState();
}

class _TrackingMapPageState extends State<TrackingMapPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootTracking();
    });
  }

  Future<void> _bootTracking() async {
    final t = context.read<TrackingService>(); // await 前讀取
    try {
      await t.init();
      if (!mounted) return;

      if (!t.tracking) {
        await t.startLocalTracking();
        if (!mounted) return;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingService>();
    final dynamic sos = context.watch<SOSService>();
    final local = tracking.lastLocal;
    final remote = tracking.lastRemote;
    final history = tracking.history;

    final bool sosActive = (sos.active == true);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        title: const Text(
          '即時追蹤',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: tracking.tracking ? '停止追蹤' : '開始追蹤',
            icon: Icon(
              tracking.tracking ? Icons.pause_circle : Icons.play_circle,
            ),
            onPressed: () async {
              if (tracking.tracking) {
                await tracking.stopLocalTracking();
                if (!mounted) return;

                _safePushNotice(title: '追蹤停止', message: '已停止定位追蹤');
                _toast('已停止追蹤');
              } else {
                await tracking.startLocalTracking();
                if (!mounted) return;

                _safePushNotice(title: '追蹤開始', message: '定位追蹤已啟動（模擬）');
                _toast('已開始追蹤');
              }
            },
          ),
          IconButton(
            tooltip: '清除軌跡',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await tracking.clearHistory();
              if (!mounted) return;
              _toast('已清除歷史軌跡');
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TrackingMapPainter(
                          history: history,
                          local: local,
                          remote: remote,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _LegendCard(
                        tracking: tracking.tracking,
                        local: local,
                        remote: remote,
                        count: history.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (local != null)
            _LocationTile(
              icon: Icons.person_pin_circle_outlined,
              color: Colors.blue,
              title: '本機位置',
              subtitle:
                  'Lat: ${local.lat.toStringAsFixed(5)}, Lng: ${local.lng.toStringAsFixed(5)}',
              time: local.time,
              onTap: () => _openMap(local.lat, local.lng),
            ),
          if (remote != null)
            _LocationTile(
              icon: Icons.watch_outlined,
              color: Colors.teal,
              title: '遠端設備',
              subtitle:
                  'Lat: ${remote.lat.toStringAsFixed(5)}, Lng: ${remote.lng.toStringAsFixed(5)}',
              time: remote.time,
              onTap: () => _openMap(remote.lat, remote.lng),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Google Maps'),
                    onPressed: () {
                      final p = local ?? remote;
                      if (p != null) {
                        _openMap(p.lat, p.lng);
                      } else {
                        _toast('目前沒有座標');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sosActive
                          ? Colors.grey
                          : Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.sos_outlined),
                    label: Text(sosActive ? '取消 SOS' : '啟動 SOS'),
                    onPressed: () async {
                      try {
                        if (!sosActive) {
                          await sos.triggerSOS(reason: 'Tracking 快捷 SOS');
                          if (!mounted) return;
                          _toast('已發出 SOS 警報');
                        } else {
                          await sos.cancelSOS();
                          if (!mounted) return;
                          _toast('已取消 SOS');
                        }
                      } catch (e) {
                        if (!mounted) return;
                        _toast('SOS 操作失敗：$e');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _safePushNotice({required String title, required String message}) {
    try {
      final dynamic ns = NotificationService.instance;
      ns.push(type: 'tracking', title: title, message: message);
    } catch (_) {}
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    final ok = await canLaunchUrl(url);
    if (!mounted) return;

    if (ok) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
    } else {
      _toast('無法開啟地圖');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}

// ======================================================
// 地圖 Legend
// ======================================================
class _LegendCard extends StatelessWidget {
  final bool tracking;
  final TrackingPoint? local;
  final TrackingPoint? remote;
  final int count;

  const _LegendCard({
    required this.tracking,
    required this.local,
    required this.remote,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black87,
          height: 1.25,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tracking ? '追蹤中（模擬）' : '未追蹤',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            // ✅ 這段就是你 lint 提示的位置：改成全 const
            const Row(
              children: [
                _Dot(color: Colors.blue),
                SizedBox(width: 6),
                Text('本機'),
                SizedBox(width: 10),
                _Dot(color: Colors.teal),
                SizedBox(width: 6),
                Text('遠端'),
                SizedBox(width: 10),
                _Dot(color: Colors.red),
                SizedBox(width: 6),
                Text('終點'),
              ],
            ),

            const SizedBox(height: 6),
            Text('軌跡點數：$count'),
            Text(
              '本機：${local == null ? '—' : 'OK'}  •  遠端：${remote == null ? '—' : 'OK'}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ======================================================
// CustomPainter：畫軌跡 + 點位
// ======================================================
class _TrackingMapPainter extends CustomPainter {
  final List<TrackingPoint> history;
  final TrackingPoint? local;
  final TrackingPoint? remote;

  _TrackingMapPainter({
    required this.history,
    required this.local,
    required this.remote,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    final points = <TrackingPoint>[
      ...history,
      if (local != null) local!,
      if (remote != null) remote!,
    ];
    if (points.isEmpty) return;

    final lats = points.map((e) => e.lat).toList();
    final lngs = points.map((e) => e.lng).toList();

    final minLat = lats.reduce(min);
    final maxLat = lats.reduce(max);
    final minLng = lngs.reduce(min);
    final maxLng = lngs.reduce(max);

    double toX(double lng) =>
        (lng - minLng) / ((maxLng - minLng) + 1e-9) * size.width;
    double toY(double lat) =>
        size.height - (lat - minLat) / ((maxLat - minLat) + 1e-9) * size.height;

    if (history.length >= 2) {
      final path = Path();
      for (int i = 0; i < history.length; i++) {
        final p = history[i];
        final x = toX(p.lng);
        final y = toY(p.lat);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final paintLine = Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.85)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, paintLine);
    }

    if (history.isNotEmpty) {
      final end = history.last;
      final endPos = Offset(toX(end.lng), toY(end.lat));
      canvas.drawCircle(endPos, 6, Paint()..color = Colors.red);
    }

    if (local != null) {
      final o = Offset(toX(local!.lng), toY(local!.lat));
      canvas.drawCircle(o, 7, Paint()..color = Colors.blue);
      _drawLabel(canvas, o, '本機', Colors.blue);
    }

    if (remote != null) {
      final o = Offset(toX(remote!.lng), toY(remote!.lat));
      canvas.drawCircle(o, 7, Paint()..color = Colors.teal);
      _drawLabel(canvas, o, '遠端', Colors.teal);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _drawLabel(Canvas canvas, Offset at, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: ' $text ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          backgroundColor: color.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pos = Offset(at.dx + 8, at.dy - tp.height - 8);
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _TrackingMapPainter oldDelegate) {
    return oldDelegate.history.length != history.length ||
        oldDelegate.local?.lat != local?.lat ||
        oldDelegate.local?.lng != local?.lng ||
        oldDelegate.remote?.lat != remote?.lat ||
        oldDelegate.remote?.lng != remote?.lng;
  }
}

// ======================================================
// 資訊 Tile
// ======================================================
class _LocationTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime time;
  final VoidCallback onTap;

  const _LocationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$subtitle\n更新於 $timeStr'),
        isThreeLine: true,
      ),
    );
  }
}
