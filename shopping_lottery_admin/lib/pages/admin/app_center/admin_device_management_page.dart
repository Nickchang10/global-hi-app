// lib/pages/admin/app_center/admin_device_management_page.dart
//
// ✅ AdminDeviceManagementPage（單檔完整版｜可編譯＋可用）
// ------------------------------------------------------------
// 裝置管理（後台）
// - Firestore：devices（collection）
// - 功能：
//   1) 裝置清單（Stream）
//   2) 搜尋（deviceId / model / boundUserId / firmware）
//   3) 篩選（全部 / 已綁定 / 未綁定 / 啟用 / 停用）
//   4) 新增裝置（docId = deviceId）
//   5) 編輯裝置（常用欄位）
//   6) 解除綁定（boundUserId/boundAt 清空）
//   7) 送指令（寫入 devices/{id}/commands）
//   8) 複製 deviceId
//
// 建議 devices/{deviceId} 結構（可依你現況調整）：
// {
//   deviceId: "ED1000_001",
//   model: "ED1000",
//   status: "active", // active / inactive
//   firmwareVersion: "1.0.3",
//   targetFirmware: "1.0.5",
//   boundUserId: "uid_xxx",
//   boundAt: Timestamp,
//   lastSeenAt: Timestamp,
//   battery: 87, // 0~100
//   notes: "",
//   createdAt: Timestamp,
//   updatedAt: Timestamp
// }
//
// commands subcollection：devices/{deviceId}/commands/{autoId}
// {
//   type: "sync" | "reboot" | "firmware_check",
//   payload: {...},
//   status: "pending",
//   createdAt: Timestamp
// }
// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminDeviceManagementPage extends StatefulWidget {
  const AdminDeviceManagementPage({super.key});

  @override
  State<AdminDeviceManagementPage> createState() => _AdminDeviceManagementPageState();
}

class _AdminDeviceManagementPageState extends State<AdminDeviceManagementPage> {
  final _db = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _col = _db.collection('devices');

  final _search = TextEditingController();
  DeviceFilter _filter = DeviceFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ 不依賴特定欄位 orderBy（避免你的 devices 尚未補欄位導致 query 直接炸）
    final query = _col.orderBy(FieldPath.documentId).limit(300);

    return Scaffold(
      appBar: AppBar(
        title: const Text('裝置管理', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: '新增裝置',
            icon: const Icon(Icons.add),
            onPressed: _openCreateDialog,
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              title: '載入失敗',
              message: snap.error.toString(),
              hint: '請確認 Firestore rules 是否允許 admin 讀取 devices。',
              onRetry: () => setState(() {}),
            );
          }

          final docs = snap.data?.docs ?? const [];
          final devices = docs.map((d) => AdminDevice.fromDoc(d)).toList();

          // ✅ 優先用 lastSeenAt/updatedAt 進行顯示排序（若存在）
          devices.sort((a, b) {
            final atA = a.lastSeenAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final atB = b.lastSeenAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return atB.compareTo(atA);
          });

          final filtered = _applyFilter(devices, _search.text, _filter);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _HeaderCard(
                total: devices.length,
                showing: filtered.length,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜尋 deviceId / model / boundUserId / firmware',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              if (filtered.isEmpty)
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '沒有符合條件的裝置。',
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                ...filtered.map((d) => _DeviceTile(
                      device: d,
                      onCopyId: () => _copy(d.deviceId),
                      onEdit: () => _openEditDialog(d),
                      onUnbind: d.boundUserId.isEmpty ? null : () => _unbind(d.deviceId),
                      onSendCommand: () => _openCommandDialog(d.deviceId),
                      onDelete: () => _deleteDevice(d.deviceId),
                    )),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // Filter
  // ============================================================

  List<AdminDevice> _applyFilter(List<AdminDevice> list, String query, DeviceFilter filter) {
    final q = query.trim().toLowerCase();

    Iterable<AdminDevice> out = list;

    if (filter == DeviceFilter.bound) {
      out = out.where((d) => d.boundUserId.isNotEmpty);
    } else if (filter == DeviceFilter.unbound) {
      out = out.where((d) => d.boundUserId.isEmpty);
    } else if (filter == DeviceFilter.active) {
      out = out.where((d) => d.status == 'active');
    } else if (filter == DeviceFilter.inactive) {
      out = out.where((d) => d.status == 'inactive');
    }

    if (q.isNotEmpty) {
      out = out.where((d) {
        return d.deviceId.toLowerCase().contains(q) ||
            d.model.toLowerCase().contains(q) ||
            d.boundUserId.toLowerCase().contains(q) ||
            d.firmwareVersion.toLowerCase().contains(q) ||
            d.targetFirmware.toLowerCase().contains(q);
      });
    }

    return out.toList();
  }

  // ============================================================
  // CRUD
  // ============================================================

  Future<void> _openCreateDialog() async {
    final idCtrl = TextEditingController();
    final modelCtrl = TextEditingController(text: 'ED1000');
    final fwCtrl = TextEditingController();
    final targetFwCtrl = TextEditingController();
    final boundCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    String status = 'active';
    bool? ok;

    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('新增裝置', style: TextStyle(fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(
                          labelText: 'deviceId（唯一，建議當 docId）',
                          helperText: '僅建議使用英數、底線、減號（避免特殊字元）',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: modelCtrl,
                        decoration: const InputDecoration(labelText: '型號（model）'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('啟用（active）')),
                          DropdownMenuItem(value: 'inactive', child: Text('停用（inactive）')),
                        ],
                        onChanged: (v) => setLocal(() => status = v ?? 'active'),
                        decoration: const InputDecoration(labelText: '狀態（status）'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: fwCtrl,
                        decoration: const InputDecoration(labelText: '目前韌體（firmwareVersion，可空）'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: targetFwCtrl,
                        decoration: const InputDecoration(labelText: '目標韌體（targetFirmware，可空）'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: boundCtrl,
                        decoration: const InputDecoration(
                          labelText: '綁定使用者（boundUserId，可空）',
                          helperText: '若要先綁定，填入 uid；不填代表未綁定',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: '備註（notes，可空）'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('建立'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      // ignore: unused_local_variable
      final _ = ok;
    }

    if (ok != true) {
      idCtrl.dispose();
      modelCtrl.dispose();
      fwCtrl.dispose();
      targetFwCtrl.dispose();
      boundCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final deviceId = idCtrl.text.trim();
    if (deviceId.isEmpty) {
      _toast('deviceId 不可為空');
      idCtrl.dispose();
      modelCtrl.dispose();
      fwCtrl.dispose();
      targetFwCtrl.dispose();
      boundCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    try {
      final ref = _col.doc(deviceId);

      await ref.set({
        'deviceId': deviceId,
        'model': modelCtrl.text.trim(),
        'status': status,
        'firmwareVersion': fwCtrl.text.trim(),
        'targetFirmware': targetFwCtrl.text.trim(),
        'boundUserId': boundCtrl.text.trim(),
        'boundAt': boundCtrl.text.trim().isEmpty ? null : FieldValue.serverTimestamp(),
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _toast('已新增裝置：$deviceId');
    } catch (e) {
      _toast('新增失敗：$e');
    } finally {
      idCtrl.dispose();
      modelCtrl.dispose();
      fwCtrl.dispose();
      targetFwCtrl.dispose();
      boundCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<void> _openEditDialog(AdminDevice d) async {
    final modelCtrl = TextEditingController(text: d.model);
    final fwCtrl = TextEditingController(text: d.firmwareVersion);
    final targetFwCtrl = TextEditingController(text: d.targetFirmware);
    final boundCtrl = TextEditingController(text: d.boundUserId);
    final notesCtrl = TextEditingController(text: d.notes);
    final batteryCtrl = TextEditingController(text: d.battery?.toString() ?? '');

    String status = d.status;
    bool? ok;

    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('編輯裝置：${d.deviceId}', style: const TextStyle(fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _readonlyRow('deviceId', d.deviceId),
                      const SizedBox(height: 10),
                      TextField(
                        controller: modelCtrl,
                        decoration: const InputDecoration(labelText: '型號（model）'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('啟用（active）')),
                          DropdownMenuItem(value: 'inactive', child: Text('停用（inactive）')),
                        ],
                        onChanged: (v) => setLocal(() => status = v ?? 'active'),
                        decoration: const InputDecoration(labelText: '狀態（status）'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: fwCtrl,
                        decoration: const InputDecoration(labelText: '目前韌體（firmwareVersion）'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: targetFwCtrl,
                        decoration: const InputDecoration(labelText: '目標韌體（targetFirmware）'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: boundCtrl,
                        decoration: const InputDecoration(
                          labelText: '綁定使用者（boundUserId）',
                          helperText: '清空代表未綁定',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: batteryCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '電量（battery，0~100，可空）',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: '備註（notes）'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('儲存'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      // ignore: unused_local_variable
      final _ = ok;
    }

    if (ok != true) {
      modelCtrl.dispose();
      fwCtrl.dispose();
      targetFwCtrl.dispose();
      boundCtrl.dispose();
      notesCtrl.dispose();
      batteryCtrl.dispose();
      return;
    }

    try {
      final boundUserId = boundCtrl.text.trim();
      final battery = int.tryParse(batteryCtrl.text.trim());

      await _col.doc(d.deviceId).set({
        'model': modelCtrl.text.trim(),
        'status': status,
        'firmwareVersion': fwCtrl.text.trim(),
        'targetFirmware': targetFwCtrl.text.trim(),
        'boundUserId': boundUserId,
        'boundAt': boundUserId.isEmpty ? null : (d.boundUserId.isEmpty ? FieldValue.serverTimestamp() : d.boundAt),
        'battery': battery,
        'notes': notesCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _toast('已更新：${d.deviceId}');
    } catch (e) {
      _toast('更新失敗：$e');
    } finally {
      modelCtrl.dispose();
      fwCtrl.dispose();
      targetFwCtrl.dispose();
      boundCtrl.dispose();
      notesCtrl.dispose();
      batteryCtrl.dispose();
    }
  }

  Future<void> _unbind(String deviceId) async {
    final ok = await _confirm(
      title: '解除綁定',
      message: '確定解除該裝置的綁定？\n\ndeviceId: $deviceId\n\n將清空 boundUserId / boundAt。',
      confirmText: '解除',
      danger: true,
    );
    if (ok != true) return;

    try {
      await _col.doc(deviceId).set({
        'boundUserId': '',
        'boundAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _toast('已解除綁定：$deviceId');
    } catch (e) {
      _toast('解除綁定失敗：$e');
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    final ok = await _confirm(
      title: '刪除裝置',
      message: '確定刪除該裝置？\n\ndeviceId: $deviceId\n\n此操作無法復原。',
      confirmText: '刪除',
      danger: true,
    );
    if (ok != true) return;

    try {
      await _col.doc(deviceId).delete();
      _toast('已刪除：$deviceId');
    } catch (e) {
      _toast('刪除失敗：$e');
    }
  }

  Future<void> _openCommandDialog(String deviceId) async {
    String type = 'sync';
    final payloadCtrl = TextEditingController(text: '{}');
    bool? ok;

    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('送指令：$deviceId', style: const TextStyle(fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'sync', child: Text('sync（要求同步）')),
                        DropdownMenuItem(value: 'reboot', child: Text('reboot（要求重啟）')),
                        DropdownMenuItem(value: 'firmware_check', child: Text('firmware_check（檢查韌體）')),
                      ],
                      onChanged: (v) => setLocal(() => type = v ?? 'sync'),
                      decoration: const InputDecoration(labelText: '指令類型（type）'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: payloadCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'payload（JSON，可空）',
                        helperText: '例如：{"force":true}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.send),
                  label: const Text('送出'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      // ignore: unused_local_variable
      final _ = ok;
    }

    if (ok != true) {
      payloadCtrl.dispose();
      return;
    }

    try {
      await _col.doc(deviceId).collection('commands').add({
        'type': type,
        'payload': payloadCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _toast('已送出指令：$type');
    } catch (e) {
      _toast('送出失敗：$e');
    } finally {
      payloadCtrl.dispose();
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已複製：$text');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _readonlyRow(String k, String v) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w900))),
        Expanded(child: SelectableText(v)),
        IconButton(
          tooltip: '複製',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => _copy(v),
        ),
      ],
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? cs.error : null,
              foregroundColor: danger ? cs.onError : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Model
// ============================================================

class AdminDevice {
  final String deviceId;
  final String model;
  final String status; // active / inactive
  final String firmwareVersion;
  final String targetFirmware;
  final String boundUserId;
  final DateTime? boundAt;
  final DateTime? lastSeenAt;
  final int? battery;
  final String notes;
  final DateTime? updatedAt;

  AdminDevice({
    required this.deviceId,
    required this.model,
    required this.status,
    required this.firmwareVersion,
    required this.targetFirmware,
    required this.boundUserId,
    required this.boundAt,
    required this.lastSeenAt,
    required this.battery,
    required this.notes,
    required this.updatedAt,
  });

  factory AdminDevice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};
    DateTime? toDt(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final deviceId = (m['deviceId'] ?? doc.id).toString();

    return AdminDevice(
      deviceId: deviceId,
      model: (m['model'] ?? '').toString(),
      status: (m['status'] ?? 'active').toString(),
      firmwareVersion: (m['firmwareVersion'] ?? '').toString(),
      targetFirmware: (m['targetFirmware'] ?? '').toString(),
      boundUserId: (m['boundUserId'] ?? '').toString(),
      boundAt: toDt(m['boundAt']),
      lastSeenAt: toDt(m['lastSeenAt']),
      battery: toInt(m['battery']),
      notes: (m['notes'] ?? '').toString(),
      updatedAt: toDt(m['updatedAt']),
    );
  }
}

enum DeviceFilter { all, bound, unbound, active, inactive }

// ============================================================
// UI
// ============================================================

class _HeaderCard extends StatelessWidget {
  final int total;
  final int showing;
  final DeviceFilter filter;
  final ValueChanged<DeviceFilter> onFilterChanged;

  const _HeaderCard({
    required this.total,
    required this.showing,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String label(DeviceFilter f) {
      switch (f) {
        case DeviceFilter.bound:
          return '已綁定';
        case DeviceFilter.unbound:
          return '未綁定';
        case DeviceFilter.active:
          return '啟用';
        case DeviceFilter.inactive:
          return '停用';
        case DeviceFilter.all:
        default:
          return '全部';
      }
    }

    DeviceFilter? byLabel(String s) {
      for (final f in DeviceFilter.values) {
        if (label(f) == s) return f;
      }
      return null;
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.watch_outlined, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('裝置清單', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('共 $total 台｜目前顯示 $showing 台',
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            DropdownButton<String>(
              value: label(filter),
              onChanged: (v) {
                final f = v == null ? null : byLabel(v);
                if (f != null) onFilterChanged(f);
              },
              items: DeviceFilter.values
                  .map((f) => DropdownMenuItem(value: label(f), child: Text(label(f))))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final AdminDevice device;
  final VoidCallback onCopyId;
  final VoidCallback onEdit;
  final VoidCallback? onUnbind;
  final VoidCallback onSendCommand;
  final VoidCallback onDelete;

  const _DeviceTile({
    required this.device,
    required this.onCopyId,
    required this.onEdit,
    required this.onUnbind,
    required this.onSendCommand,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isActive = device.status == 'active';
    final bound = device.boundUserId.isNotEmpty;

    final pillBg = isActive ? Colors.green.shade100 : Colors.grey.shade200;
    final pillFg = isActive ? Colors.green.shade900 : cs.onSurfaceVariant;

    String fmtDt(DateTime? dt) {
      if (dt == null) return '—';
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    }

    final line1 = '${device.deviceId}  •  ${device.model.isEmpty ? "—" : device.model}';
    final line2 = '狀態=${device.status}  •  綁定=${bound ? "Y" : "N"}'
        '${device.firmwareVersion.isNotEmpty ? "  •  fw=${device.firmwareVersion}" : ""}'
        '${device.targetFirmware.isNotEmpty ? "  •  target=${device.targetFirmware}" : ""}'
        '${device.battery != null ? "  •  batt=${device.battery}%" : ""}'
        '  •  lastSeen=${fmtDt(device.lastSeenAt)}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? cs.primaryContainer : Colors.grey.shade200,
          child: Icon(Icons.devices_other_outlined,
              color: isActive ? cs.onPrimaryContainer : Colors.grey.shade600),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(line1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(999)),
              child: Text(isActive ? '啟用' : '停用',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: pillFg)),
            ),
          ],
        ),
        subtitle: Text(
          '$line2\n'
          'boundUserId=${device.boundUserId.isEmpty ? "—" : device.boundUserId}  •  boundAt=${fmtDt(device.boundAt)}'
          '${device.notes.isNotEmpty ? "\n備註：${device.notes}" : ""}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, height: 1.25),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (v) {
            if (v == 'copy') onCopyId();
            if (v == 'edit') onEdit();
            if (v == 'cmd') onSendCommand();
            if (v == 'unbind' && onUnbind != null) onUnbind!();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy',
              child: Row(children: [Icon(Icons.copy), SizedBox(width: 10), Text('複製 deviceId')]),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit_outlined), SizedBox(width: 10), Text('編輯')]),
            ),
            const PopupMenuItem(
              value: 'cmd',
              child: Row(children: [Icon(Icons.send), SizedBox(width: 10), Text('送指令')]),
            ),
            if (onUnbind != null)
              PopupMenuItem(
                value: 'unbind',
                child: Row(
                  children: [
                    Icon(Icons.link_off, color: cs.error),
                    const SizedBox(width: 10),
                    const Text('解除綁定', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: cs.error),
                  const SizedBox(width: 10),
                  const Text('刪除', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 44, color: cs.error),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (hint != null) ...[
                    const SizedBox(height: 10),
                    Text(hint!, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
