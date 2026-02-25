// lib/pages/admin/app_center/admin_device_management_page.dart
//
// ✅ AdminDeviceManagementPage（完整版｜可編譯＋可用）
// ✅ 已修正：DropdownButtonFormField value deprecated → initialValue
// ✅ 已修正：curly_braces_in_flow_control_structures（所有 if 均加上 {}）
// ✅ 已修正：use_build_context_synchronously（Dialog ctx 用 ctx.mounted；State.context 用 mounted）
//
// Firestore 建議結構：devices (collection)
// doc fields:
// {
//   serial: "SN0001",
//   imei: "123456789012345",
//   model: "ED1000",
//   status: "active" | "inactive" | "lost" | "repair" | "retired",
//   enabled: true,
//   ownerUid: "uid(optional)",
//   note: "備註(optional)",
//   createdAt: Timestamp,
//   updatedAt: Timestamp
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDeviceManagementPage extends StatefulWidget {
  const AdminDeviceManagementPage({super.key});

  static const String routeName = '/admin-device-management';

  @override
  State<AdminDeviceManagementPage> createState() =>
      _AdminDeviceManagementPageState();
}

class _AdminDeviceManagementPageState extends State<AdminDeviceManagementPage> {
  final _db = FirebaseFirestore.instance;

  final _searchCtrl = TextEditingController();
  String _statusFilter =
      'all'; // all / active / inactive / lost / repair / retired

  static const List<String> _statusKeys = <String>[
    'all',
    'active',
    'inactive',
    'lost',
    'repair',
    'retired',
  ];

  static const Map<String, String> _statusLabel = <String, String>{
    'all': '全部',
    'active': '啟用中',
    'inactive': '停用',
    'lost': '遺失',
    'repair': '維修',
    'retired': '報廢',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _baseQuery() {
    var q = _db.collection('devices').orderBy('updatedAt', descending: true);

    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }

    return q;
  }

  bool _matchSearch(Map<String, dynamic> d, String keyword) {
    if (keyword.isEmpty) {
      return true;
    }

    final k = keyword.toLowerCase();

    String s(dynamic v) => (v ?? '').toString().toLowerCase();

    return s(d['serial']).contains(k) ||
        s(d['imei']).contains(k) ||
        s(d['model']).contains(k) ||
        s(d['ownerUid']).contains(k);
  }

  Future<void> _createOrEdit({
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final initial = doc?.data() ?? <String, dynamic>{};

    final serialCtrl = TextEditingController(
      text: (initial['serial'] ?? '').toString(),
    );
    final imeiCtrl = TextEditingController(
      text: (initial['imei'] ?? '').toString(),
    );
    final modelCtrl = TextEditingController(
      text: (initial['model'] ?? '').toString(),
    );
    final ownerCtrl = TextEditingController(
      text: (initial['ownerUid'] ?? '').toString(),
    );
    final noteCtrl = TextEditingController(
      text: (initial['note'] ?? '').toString(),
    );

    String status = (initial['status'] ?? 'active').toString();
    if (!_statusKeys.contains(status) || status == 'all') {
      status = 'active';
    }

    bool enabled = (initial['enabled'] as bool?) ?? true;

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (outerDialogCtx) {
        // outerDialogCtx 只用於建構 UI，不在 await 後使用
        final cs = Theme.of(outerDialogCtx).colorScheme;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            // ✅ ctx = 這個 dialog 內的 BuildContext
            return AlertDialog(
              title: Text(doc == null ? '新增設備' : '編輯設備'),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: serialCtrl,
                        decoration: const InputDecoration(
                          labelText: '序號 Serial',
                          hintText: '例如：SN0001',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Serial 不能為空';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: imeiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'IMEI（可空）',
                          hintText: '例如：123456789012345',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: modelCtrl,
                        decoration: const InputDecoration(
                          labelText: '型號 Model（可空）',
                          hintText: '例如：ED1000',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ✅ value deprecated → initialValue
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: '狀態 Status',
                        ),
                        items:
                            const <String>[
                              'active',
                              'inactive',
                              'lost',
                              'repair',
                              'retired',
                            ].map((k) {
                              return DropdownMenuItem<String>(
                                value: k,
                                child: Text(_statusLabel[k] ?? k),
                              );
                            }).toList(),
                        onChanged: saving
                            ? null
                            : (v) {
                                if (v == null) {
                                  return;
                                }
                                setStateDialog(() {
                                  status = v;
                                });
                              },
                      ),

                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: enabled,
                        onChanged: saving
                            ? null
                            : (v) {
                                setStateDialog(() {
                                  enabled = v;
                                });
                              },
                        title: const Text('啟用 enabled'),
                        subtitle: const Text('停用不代表報廢，只是暫停使用'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ownerCtrl,
                        decoration: const InputDecoration(
                          labelText: '綁定使用者 UID（可空）',
                          hintText: '例如：FirebaseAuth uid',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: '備註（可空）'),
                      ),
                      if (saving) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('儲存中...'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(ctx).pop(false);
                        },
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          setStateDialog(() {
                            saving = true;
                          });

                          final payload = <String, dynamic>{
                            'serial': serialCtrl.text.trim(),
                            'imei': imeiCtrl.text.trim(),
                            'model': modelCtrl.text.trim(),
                            'status': status,
                            'enabled': enabled,
                            'ownerUid': ownerCtrl.text.trim(),
                            'note': noteCtrl.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          };

                          try {
                            if (doc == null) {
                              await _db.collection('devices').add({
                                ...payload,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await _db
                                  .collection('devices')
                                  .doc(doc.id)
                                  .set(payload, SetOptions(merge: true));
                            }

                            // ✅ await 後使用的是「dialog ctx」→ 用 ctx.mounted 守
                            if (!ctx.mounted) {
                              return;
                            }
                            Navigator.of(ctx).pop(true);
                          } catch (e) {
                            // ✅ await 後要更新 dialog 狀態 → 也要用 ctx.mounted 守
                            if (!ctx.mounted) {
                              return;
                            }
                            setStateDialog(() {
                              saving = false;
                            });

                            // ✅ 這裡用的是 State.context → 用 mounted 守
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
                          }
                        },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );

    serialCtrl.dispose();
    imeiCtrl.dispose();
    modelCtrl.dispose();
    ownerCtrl.dispose();
    noteCtrl.dispose();

    if (result == true) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(doc == null ? '已新增設備' : '已更新設備')));
    }
  }

  Future<void> _deleteDevice(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final name = (data['serial'] ?? doc.id).toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除設備'),
        content: Text('確定要刪除「$name」？此動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    try {
      await _db.collection('devices').doc(doc.id).delete();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除設備')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '設備管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '新增設備',
            icon: const Icon(Icons.add),
            onPressed: () {
              _createOrEdit();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜尋 serial / imei / model / ownerUid',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: '狀態篩選',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _statusKeys.map((k) {
                      return DropdownMenuItem<String>(
                        value: k,
                        child: Text(_statusLabel[k] ?? k),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v == null) {
                        return;
                      }
                      setState(() {
                        _statusFilter = v;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _baseQuery().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('載入失敗：${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                final keyword = _searchCtrl.text.trim();
                final filtered = docs
                    .where((d) => _matchSearch(d.data(), keyword))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('沒有符合條件的設備'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final d = doc.data();
                    final serial = (d['serial'] ?? doc.id).toString();
                    final imei = (d['imei'] ?? '').toString();
                    final model = (d['model'] ?? '').toString();
                    final owner = (d['ownerUid'] ?? '').toString();
                    final status = (d['status'] ?? 'active').toString();
                    final enabled = (d['enabled'] as bool?) ?? true;

                    return Card(
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primary.withValues(alpha: 0.10),
                          child: Icon(Icons.watch, color: cs.primary),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                serial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(status: status, enabled: enabled),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (model.isNotEmpty) Text('Model: $model'),
                              if (imei.isNotEmpty) Text('IMEI: $imei'),
                              if (owner.isNotEmpty) Text('OwnerUid: $owner'),
                            ],
                          ),
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: '編輯',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                _createOrEdit(doc: doc);
                              },
                            ),
                            IconButton(
                              tooltip: '刪除',
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade400,
                              ),
                              onPressed: () {
                                _deleteDevice(doc);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool enabled;

  const _StatusChip({required this.status, required this.enabled});

  String _label(String s) {
    switch (s) {
      case 'active':
        return '啟用中';
      case 'inactive':
        return '停用';
      case 'lost':
        return '遺失';
      case 'repair':
        return '維修';
      case 'retired':
        return '報廢';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color tone;
    if (!enabled) {
      tone = cs.outline;
    } else {
      switch (status) {
        case 'active':
          tone = cs.primary;
          break;
        case 'inactive':
          tone = cs.tertiary;
          break;
        case 'lost':
          tone = cs.error;
          break;
        case 'repair':
          tone = Colors.orange;
          break;
        case 'retired':
          tone = Colors.grey;
          break;
        default:
          tone = cs.secondary;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Text(
        enabled ? _label(status) : '停用',
        style: TextStyle(
          color: tone,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
