// ignore_for_file: prefer_const_constructors, prefer_const_declarations

// lib/pages/device_page.dart
// =====================================================
// ✅ DevicePage（手錶配對頁｜最終完整版｜已修正：withValues alpha 型別 + const 建議）
// =====================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/bluetooth_service.dart';
import '../services/health_service.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'demo_user';

  final TextEditingController _nameCtrl = TextEditingController(text: 'Osmile');
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  double _a(double opacity) {
    if (opacity.isNaN) return 1.0;
    if (opacity < 0) return 0.0;
    if (opacity > 1) return 1.0;
    return opacity;
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BluetoothService>();
    final health = context.watch<HealthService>();

    final connected = ble.isConnected;
    final devName = (ble.deviceName ?? '').trim().isEmpty
        ? '未連線'
        : (ble.deviceName ?? '未連線');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          '手錶配對',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: '刷新雲端健康資料',
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await HealthService.instance.syncFromCloud(_userId);
                      _toast('已從雲端刷新');
                    } catch (e) {
                      _toast('雲端刷新失敗：$e');
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          _toast('已更新（模板）');
        },
        child: ListView(
          padding: const EdgeInsets.all(14),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _infoBanner(connected: connected, deviceName: devName),
            const SizedBox(height: 12),
            _card(
              title: '配對與連線',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusRow(connected: connected, deviceName: devName),
                  const SizedBox(height: 12),
                  const Text(
                    '偏好裝置名稱（搜尋用）',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: '例如：Osmile / ED1000',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    final name = _nameCtrl.text.trim().isEmpty
                                        ? 'Osmile'
                                        : _nameCtrl.text.trim();
                                    await BluetoothService.instance
                                        .scanAndConnect(preferredName: name);
                                    _toast(
                                      '已連線：${BluetoothService.instance.deviceName ?? '裝置'}',
                                    );
                                  } catch (e) {
                                    _toast('連線失敗：$e');
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bluetooth_connected),
                          label: Text(connected ? '重新連線' : '搜尋並連線'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy || !connected
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    await BluetoothService.instance
                                        .disconnect();
                                    await HealthService.instance.stop();
                                    _toast('已斷線');
                                  } catch (e) {
                                    _toast('斷線失敗：$e');
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          icon: const Icon(Icons.link_off),
                          label: const Text('斷線'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              title: '健康同步',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                (health.online ? Colors.green : Colors.grey)
                                    .withValues(alpha: _a(0.12)),
                            child: Icon(
                              health.online
                                  ? Icons.check_circle_outline
                                  : Icons.sync_problem_outlined,
                              color: health.online ? Colors.green : Colors.grey,
                            ),
                          ),
                          title: Text(
                            health.online ? '同步中' : '未同步',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '來源：${health.lastSource}  •  '
                            '${health.lastUpdated == null ? '未更新' : _hhmmss(health.lastUpdated!)}',
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await HealthService.instance.startLocalSync(
                                    _userId,
                                  );
                                  _toast(kIsWeb ? 'Web 模擬同步已啟動' : '手錶同步已啟動');
                                } catch (e) {
                                  _toast('啟動失敗：$e');
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('開始'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await HealthService.instance.stop();
                                  _toast('已停止同步');
                                } catch (e) {
                                  _toast('停止失敗：$e');
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: const Text('停止'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: _miniMetric(
                          '步數',
                          '${health.steps}',
                          Icons.directions_walk,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _miniMetric(
                          '心率',
                          '${health.heartRate} bpm',
                          Icons.favorite_border,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _miniMetric(
                          '睡眠',
                          '${health.sleepHours.toStringAsFixed(1)} h',
                          Icons.bedtime_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _miniMetric(
                          '血壓',
                          health.bp,
                          Icons.monitor_heart_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _miniMetric(
                          '電量',
                          '${health.battery}%',
                          Icons.battery_full,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _miniMetric(
                          '積分',
                          '${health.points}',
                          Icons.stars_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner({required bool connected, required String deviceName}) {
    const String webTxt = 'Web 模式：手錶資料會以模擬串流提供（用於展示與開發）。';
    const String mobileTxt =
        'Mobile 模式：若要真正 BLE 連線，請在原生端實作 MethodChannel(osmile/ble)。';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (connected ? Colors.green : Colors.blueAccent)
                .withValues(alpha: _a(0.12)),
            child: Icon(
              connected ? Icons.bluetooth_connected : Icons.info_outline,
              color: connected ? Colors.green : Colors.blueAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? '已連線：$deviceName' : '尚未連線',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  kIsWeb ? webTxt : mobileTxt,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({required bool connected, required String deviceName}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: connected ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            connected ? '狀態：已連線（$deviceName）' : '狀態：未連線',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: connected ? Colors.green : Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blueAccent.withValues(alpha: _a(0.12)),
            child: Icon(icon, size: 18, color: Colors.blueAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hhmmss(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
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
