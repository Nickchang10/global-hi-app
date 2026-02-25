// lib/pages/admin/app_center/admin_sos_health_page.dart
//
// ✅ AdminSosHealthPage（完整版｜可編譯＋可用）
// ------------------------------------------------------------
// ✅ 修正 deprecated：DropdownButtonFormField.value → initialValue
// ✅ 修正 no_leading_underscores_for_local_identifiers：_asInt → asInt
// ✅ 使用 PopScope + onPopInvokedWithResult（避免 WillPopScope / onPopInvoked deprecated）
// ✅ 不使用 withOpacity（改用 withAlpha）
//
// Firestore（建議固定同一份 doc，前後台才算「串接」）
// app_config/sos_health
// { ... }

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSosHealthPage extends StatefulWidget {
  const AdminSosHealthPage({super.key});

  static const String routeName = '/admin-sos-health';

  @override
  State<AdminSosHealthPage> createState() => _AdminSosHealthPageState();
}

class _AdminSosHealthPageState extends State<AdminSosHealthPage> {
  final _db = FirebaseFirestore.instance;

  /// ✅ 前後台串接固定同一份 doc
  late final DocumentReference<Map<String, dynamic>> _docRef = _db
      .collection('app_config')
      .doc('sos_health');

  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;

  // system
  bool _systemEnabled = true;

  // sos
  bool _sosEnabled = true;
  String _sosTrigger = 'watch_button_long_press';
  int _sosHoldSeconds = 3;
  int _sosCooldownSeconds = 30;
  bool _sosPushEnabled = true;
  bool _sosSmsEnabled = false;
  String _sosMessageTemplate = '我需要協助，請盡快聯絡我。';

  // health
  bool _healthEnabled = true;
  bool _hrAlertEnabled = true;
  int _hrHigh = 160;
  int _hrLow = 45;
  int _stepGoal = 8000;
  bool _sedentaryEnabled = true;
  int _sedentaryMinutes = 60;

  // dirty control
  String _baselineSig = '';
  bool _dirty = false;

  Color _alpha(Color c, double opacity01) {
    final a = (opacity01 * 255).round().clamp(0, 255);
    return c.withAlpha(a);
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _ensureDefaults();

    _docRef.snapshots().listen((snap) {
      if (!mounted) {
        return;
      }
      final data = snap.data();
      if (data == null) {
        setState(() => _loading = false);
        return;
      }

      // 若使用者已改動但未儲存，避免遠端更新覆蓋（你也可以改成提示）
      if (_dirty) {
        return;
      }

      final enabled = (data['enabled'] as bool?) ?? true;

      final sos = (data['sos'] is Map)
          ? Map<String, dynamic>.from(data['sos'] as Map)
          : <String, dynamic>{};
      final health = (data['health'] is Map)
          ? Map<String, dynamic>.from(data['health'] as Map)
          : <String, dynamic>{};

      final next = _applyFromRemote(enabled: enabled, sos: sos, health: health);

      setState(() {
        _systemEnabled = next.systemEnabled;

        _sosEnabled = next.sosEnabled;
        _sosTrigger = next.sosTrigger;
        _sosHoldSeconds = next.sosHoldSeconds;
        _sosCooldownSeconds = next.sosCooldownSeconds;
        _sosPushEnabled = next.sosPushEnabled;
        _sosSmsEnabled = next.sosSmsEnabled;
        _sosMessageTemplate = next.sosMessageTemplate;

        _healthEnabled = next.healthEnabled;
        _hrAlertEnabled = next.hrAlertEnabled;
        _hrHigh = next.hrHigh;
        _hrLow = next.hrLow;
        _stepGoal = next.stepGoal;
        _sedentaryEnabled = next.sedentaryEnabled;
        _sedentaryMinutes = next.sedentaryMinutes;

        _baselineSig = _computeSig();
        _dirty = false;
        _loading = false;
      });
    });
  }

  Future<void> _ensureDefaults() async {
    try {
      final snap = await _docRef.get();
      if (snap.exists) {
        return;
      }

      await _docRef.set(<String, dynamic>{
        'enabled': true,
        'sos': <String, dynamic>{
          'enabled': true,
          'trigger': 'watch_button_long_press',
          'holdSeconds': 3,
          'cooldownSeconds': 30,
          'pushEnabled': true,
          'smsEnabled': false,
          'messageTemplate': '我需要協助，請盡快聯絡我。',
        },
        'health': <String, dynamic>{
          'enabled': true,
          'hrAlertEnabled': true,
          'hrHigh': 160,
          'hrLow': 45,
          'stepGoal': 8000,
          'sedentaryEnabled': true,
          'sedentaryMinutes': 60,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // init 不打斷 UI
    }
  }

  _RemoteModel _applyFromRemote({
    required bool enabled,
    required Map<String, dynamic> sos,
    required Map<String, dynamic> health,
  }) {
    // ✅ 修正 lint：local identifier 不要用底線開頭
    int asInt(dynamic v, int fallback) {
      if (v is int) {
        return v;
      }
      if (v is num) {
        return v.round();
      }
      return fallback;
    }

    return _RemoteModel(
      systemEnabled: enabled,

      sosEnabled: (sos['enabled'] as bool?) ?? true,
      sosTrigger: (sos['trigger'] ?? 'watch_button_long_press').toString(),
      sosHoldSeconds: asInt(sos['holdSeconds'], 3).clamp(1, 10),
      sosCooldownSeconds: asInt(sos['cooldownSeconds'], 30).clamp(0, 3600),
      sosPushEnabled: (sos['pushEnabled'] as bool?) ?? true,
      sosSmsEnabled: (sos['smsEnabled'] as bool?) ?? false,
      sosMessageTemplate: (sos['messageTemplate'] ?? '我需要協助，請盡快聯絡我。')
          .toString(),

      healthEnabled: (health['enabled'] as bool?) ?? true,
      hrAlertEnabled: (health['hrAlertEnabled'] as bool?) ?? true,
      hrHigh: asInt(health['hrHigh'], 160).clamp(80, 240),
      hrLow: asInt(health['hrLow'], 45).clamp(30, 120),
      stepGoal: asInt(health['stepGoal'], 8000).clamp(0, 100000),
      sedentaryEnabled: (health['sedentaryEnabled'] as bool?) ?? true,
      sedentaryMinutes: asInt(health['sedentaryMinutes'], 60).clamp(10, 240),
    );
  }

  String _computeSig() {
    return jsonEncode(<String, dynamic>{
      'enabled': _systemEnabled,
      'sos': <String, dynamic>{
        'enabled': _sosEnabled,
        'trigger': _sosTrigger,
        'holdSeconds': _sosHoldSeconds,
        'cooldownSeconds': _sosCooldownSeconds,
        'pushEnabled': _sosPushEnabled,
        'smsEnabled': _sosSmsEnabled,
        'messageTemplate': _sosMessageTemplate,
      },
      'health': <String, dynamic>{
        'enabled': _healthEnabled,
        'hrAlertEnabled': _hrAlertEnabled,
        'hrHigh': _hrHigh,
        'hrLow': _hrLow,
        'stepGoal': _stepGoal,
        'sedentaryEnabled': _sedentaryEnabled,
        'sedentaryMinutes': _sedentaryMinutes,
      },
    });
  }

  void _markDirty() {
    final sig = _computeSig();
    if (!mounted) {
      return;
    }
    setState(() => _dirty = sig != _baselineSig);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _saving = true);

    try {
      await _docRef.set(<String, dynamic>{
        'enabled': _systemEnabled,
        'sos': <String, dynamic>{
          'enabled': _sosEnabled,
          'trigger': _sosTrigger,
          'holdSeconds': _sosHoldSeconds,
          'cooldownSeconds': _sosCooldownSeconds,
          'pushEnabled': _sosPushEnabled,
          'smsEnabled': _sosSmsEnabled,
          'messageTemplate': _sosMessageTemplate,
        },
        'health': <String, dynamic>{
          'enabled': _healthEnabled,
          'hrAlertEnabled': _hrAlertEnabled,
          'hrHigh': _hrHigh,
          'hrLow': _hrLow,
          'stepGoal': _stepGoal,
          'sedentaryEnabled': _sedentaryEnabled,
          'sedentaryMinutes': _sedentaryMinutes,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      setState(() {
        _baselineSig = _computeSig();
        _dirty = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存 SOS / 健康設定（前後台串接同一份 doc）')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applyDefaultsDraft() {
    if (!mounted) {
      return;
    }
    setState(() {
      _systemEnabled = true;

      _sosEnabled = true;
      _sosTrigger = 'watch_button_long_press';
      _sosHoldSeconds = 3;
      _sosCooldownSeconds = 30;
      _sosPushEnabled = true;
      _sosSmsEnabled = false;
      _sosMessageTemplate = '我需要協助，請盡快聯絡我。';

      _healthEnabled = true;
      _hrAlertEnabled = true;
      _hrHigh = 160;
      _hrLow = 45;
      _stepGoal = 8000;
      _sedentaryEnabled = true;
      _sedentaryMinutes = 60;
    });
    _markDirty();
  }

  Future<void> _confirmDiscardAndPop() async {
    if (!_dirty || _saving) {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('尚未儲存'),
        content: const Text('你有未儲存的變更，確定要放棄並離開嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放棄'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    _confirmDiscardAndPop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'SOS / 健康設定',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            TextButton.icon(
              onPressed: _saving ? null : _applyDefaultsDraft,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('套用預設'),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: (_dirty && !_saving) ? _save : null,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('儲存'),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionCard(
                      title: '系統總開關（前後台共用）',
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _systemEnabled,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() => _systemEnabled = v);
                                _markDirty();
                              },
                        title: const Text('啟用 SOS / 健康設定系統'),
                        subtitle: const Text('關閉時前台可選擇忽略本設定'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'SOS 設定',
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _sosEnabled,
                            onChanged: _saving
                                ? null
                                : (v) {
                                    setState(() => _sosEnabled = v);
                                    _markDirty();
                                  },
                            title: const Text('啟用 SOS 功能'),
                            subtitle: const Text('手錶求救 / App 收到通知等'),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _sosTrigger,
                            decoration: const InputDecoration(
                              labelText: '觸發方式（Trigger）',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'watch_button_long_press',
                                child: Text('手錶右側按鍵長按'),
                              ),
                              DropdownMenuItem(
                                value: 'watch_button_double_press',
                                child: Text('手錶按鍵連按 2 次'),
                              ),
                              DropdownMenuItem(
                                value: 'app_button',
                                child: Text('App 內求救按鈕'),
                              ),
                            ],
                            onChanged: _saving
                                ? null
                                : (v) {
                                    if (v == null) {
                                      return;
                                    }
                                    setState(() => _sosTrigger = v);
                                    _markDirty();
                                  },
                          ),
                          const SizedBox(height: 12),
                          _numberField(
                            label: '長按秒數（Hold Seconds）',
                            value: _sosHoldSeconds,
                            min: 1,
                            max: 10,
                            onChanged: (v) {
                              setState(() => _sosHoldSeconds = v);
                              _markDirty();
                            },
                          ),
                          const SizedBox(height: 12),
                          _numberField(
                            label: '冷卻秒數（Cooldown Seconds）',
                            value: _sosCooldownSeconds,
                            min: 0,
                            max: 3600,
                            onChanged: (v) {
                              setState(() => _sosCooldownSeconds = v);
                              _markDirty();
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _sosPushEnabled,
                            onChanged: _saving
                                ? null
                                : (v) {
                                    setState(() => _sosPushEnabled = v);
                                    _markDirty();
                                  },
                            title: const Text('推播通知（Push）'),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _sosSmsEnabled,
                            onChanged: _saving
                                ? null
                                : (v) {
                                    setState(() => _sosSmsEnabled = v);
                                    _markDirty();
                                  },
                            title: const Text('簡訊通知（SMS）'),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _sosMessageTemplate,
                            decoration: const InputDecoration(
                              labelText: '通知文字模板',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                            onChanged: (v) {
                              _sosMessageTemplate = v;
                              _markDirty();
                            },
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) {
                                return '模板不可空白';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: '健康設定',
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _healthEnabled,
                            onChanged: _saving
                                ? null
                                : (v) {
                                    setState(() => _healthEnabled = v);
                                    _markDirty();
                                  },
                            title: const Text('啟用健康功能'),
                            subtitle: const Text('心率警示 / 步數 / 久坐提醒等'),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _hrAlertEnabled,
                            onChanged: _saving
                                ? null
                                : (v) {
                                    setState(() => _hrAlertEnabled = v);
                                    _markDirty();
                                  },
                            title: const Text('心率警示（HR Alert）'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _numberField(
                                  label: '心率上限（HR High）',
                                  value: _hrHigh,
                                  min: 80,
                                  max: 240,
                                  onChanged: (v) {
                                    setState(() => _hrHigh = v);
                                    _markDirty();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _numberField(
                                  label: '心率下限（HR Low）',
                                  value: _hrLow,
                                  min: 30,
                                  max: 120,
                                  onChanged: (v) {
                                    setState(() => _hrLow = v);
                                    _markDirty();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _numberField(
                            label: '步數目標（Step Goal）',
                            value: _stepGoal,
                            min: 0,
                            max: 100000,
                            onChanged: (v) {
                              setState(() => _stepGoal = v);
                              _markDirty();
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _sedentaryEnabled,
                            onChanged: _saving
                                ? null
                                : (v) {
                                    setState(() => _sedentaryEnabled = v);
                                    _markDirty();
                                  },
                            title: const Text('久坐提醒（Sedentary）'),
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            label: '久坐分鐘（Sedentary Minutes）',
                            value: _sedentaryMinutes,
                            min: 10,
                            max: 240,
                            onChanged: (v) {
                              setState(() => _sedentaryMinutes = v);
                              _markDirty();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: _alpha(cs.surfaceContainerHighest, 0.6),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          '小提醒：\n'
                          '• 後台改的是 app_config/sos_health，前台/手錶端讀同一份才叫「串接」。\n'
                          '• 如果你前台拿不到值，請確認 Firestore rules 與前台讀取路徑一致。\n'
                          '• DropdownButtonFormField 已改用 initialValue，避免 value deprecated。',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      initialValue: value.toString(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: '範圍：$min ~ $max',
      ),
      keyboardType: TextInputType.number,
      validator: (v) {
        final t = (v ?? '').trim();
        final n = int.tryParse(t);
        if (n == null) {
          return '請輸入數字';
        }
        if (n < min || n > max) {
          return '請輸入 $min ~ $max';
        }
        return null;
      },
      onChanged: (v) {
        final n = int.tryParse(v.trim());
        if (n == null) {
          return;
        }
        onChanged(n.clamp(min, max));
      },
    );
  }
}

class _RemoteModel {
  final bool systemEnabled;

  final bool sosEnabled;
  final String sosTrigger;
  final int sosHoldSeconds;
  final int sosCooldownSeconds;
  final bool sosPushEnabled;
  final bool sosSmsEnabled;
  final String sosMessageTemplate;

  final bool healthEnabled;
  final bool hrAlertEnabled;
  final int hrHigh;
  final int hrLow;
  final int stepGoal;
  final bool sedentaryEnabled;
  final int sedentaryMinutes;

  const _RemoteModel({
    required this.systemEnabled,
    required this.sosEnabled,
    required this.sosTrigger,
    required this.sosHoldSeconds,
    required this.sosCooldownSeconds,
    required this.sosPushEnabled,
    required this.sosSmsEnabled,
    required this.sosMessageTemplate,
    required this.healthEnabled,
    required this.hrAlertEnabled,
    required this.hrHigh,
    required this.hrLow,
    required this.stepGoal,
    required this.sedentaryEnabled,
    required this.sedentaryMinutes,
  });
}
