import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ AIEmotionCenterPage（AI 情緒中心｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// Firestore（建議結構）
/// 1) users/{uid}/ai_emotion_logs/{logId}
///    - mood (String)        e.g. calm/happy/anxious/sad/angry/stressed/excited
///    - intensity (int)     1~5
///    - note (String)       可空
///    - tags (List<String>) 可空
///    - createdAt (Timestamp)
///    - updatedAt (Timestamp)
///
/// 2) users/{uid}/ai_emotion_state/current
///    - mood (String)
///    - intensity (int)
///    - note (String)
///    - tags (List<String>)
///    - updatedAt (Timestamp)
///
/// 功能
/// - 快速設定「目前情緒狀態」（寫入 emotion_state/current）
/// - 同步寫入一筆 log（ai_emotion_logs）
/// - 顯示最近紀錄（可刪除、可套用為目前狀態）
///
/// ✅ Lints
/// - prefer_const_constructors：能 const 的都 const
/// - curly_braces_in_flow_control_structures：if 都用 {}
/// - withOpacity deprecated：改 withValues(alpha: ...)
class AIEmotionCenterPage extends StatefulWidget {
  const AIEmotionCenterPage({super.key});

  @override
  State<AIEmotionCenterPage> createState() => _AIEmotionCenterPageState();
}

class _AIEmotionCenterPageState extends State<AIEmotionCenterPage> {
  final _fs = FirebaseFirestore.instance;

  final _noteCtrl = TextEditingController();

  String _mood = 'calm';
  int _intensity = 3; // 1~5
  final Set<String> _tags = <String>{};

  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Firestore refs
  // -------------------------
  CollectionReference<Map<String, dynamic>> _logCol(String uid) =>
      _fs.collection('users').doc(uid).collection('ai_emotion_logs');

  DocumentReference<Map<String, dynamic>> _stateDoc(String uid) => _fs
      .collection('users')
      .doc(uid)
      .collection('ai_emotion_state')
      .doc('current');

  // -------------------------
  // Mood presets
  // -------------------------
  static const List<_MoodPreset> _moods = <_MoodPreset>[
    _MoodPreset('calm', '平靜', Icons.spa),
    _MoodPreset('happy', '開心', Icons.sentiment_very_satisfied),
    _MoodPreset('excited', '興奮', Icons.bolt),
    _MoodPreset('anxious', '焦慮', Icons.psychology_alt),
    _MoodPreset('stressed', '壓力', Icons.warning_amber),
    _MoodPreset('sad', '難過', Icons.sentiment_dissatisfied),
    _MoodPreset('angry', '生氣', Icons.sentiment_very_dissatisfied),
  ];

  static const List<String> _tagPresets = <String>[
    '工作',
    '家庭',
    '健康',
    '睡眠',
    '金錢',
    '學業',
    '人際',
    '通勤',
    '運動',
    '購物',
  ];

  _MoodPreset get _currentPreset {
    for (final m in _moods) {
      if (m.key == _mood) {
        return m;
      }
    }
    return _moods.first;
  }

  // -------------------------
  // Save
  // -------------------------
  Future<void> _saveNow({required String uid, bool alsoWriteLog = true}) async {
    if (_saving) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出
    setState(() => _saving = true);

    try {
      final now = FieldValue.serverTimestamp();
      final payload = <String, dynamic>{
        'mood': _mood,
        'intensity': _intensity,
        'note': _noteCtrl.text.trim(),
        'tags': _tags.toList(),
        'updatedAt': now,
      };

      // 1) state/current
      await _stateDoc(uid).set(payload, SetOptions(merge: true));

      // 2) log
      if (alsoWriteLog) {
        await _logCol(uid).add(<String, dynamic>{...payload, 'createdAt': now});
      }

      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(content: Text('✅ 已更新目前情緒狀態')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  Future<void> _applyFromLog({
    required String uid,
    required _EmotionLog log,
  }) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    setState(() {
      _mood = log.mood;
      _intensity = log.intensity.clamp(1, 5);
      _noteCtrl.text = log.note;
      _tags
        ..clear()
        ..addAll(log.tags);
    });

    // 只更新 current，不再額外寫一筆 log（避免重複）
    await _saveNow(uid: uid, alsoWriteLog: false);

    if (!mounted) {
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('已套用為目前狀態')));
  }

  Future<void> _deleteLog({
    required String uid,
    required _EmotionLog log,
  }) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除紀錄'),
        content: Text('確定刪除這筆「${_labelOfMood(log.mood)}」紀錄嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (ok != true) {
      return;
    }

    try {
      await _logCol(uid).doc(log.id).delete();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('已刪除紀錄')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 情緒中心')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('請先登入才能使用', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed('/login'),
                  child: const Text('前往登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final uid = user.uid;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 情緒中心'),
        actions: [
          IconButton(
            tooltip: '讀取目前狀態',
            onPressed: _saving ? null : () => _loadCurrent(uid),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('目前情緒狀態'),
          _currentCard(cs, uid),
          const SizedBox(height: 16),
          _sectionTitle('最近紀錄'),
          _recentLogs(uid),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _loadCurrent(String uid) async {
    final messenger = ScaffoldMessenger.of(context); // ✅ async 前先取出

    try {
      final doc = await _stateDoc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      setState(() {
        _mood = (data['mood'] ?? _mood).toString();
        _intensity = _asInt(
          data['intensity'],
          fallback: _intensity,
        ).clamp(1, 5);
        _noteCtrl.text = (data['note'] ?? '').toString();
        _tags
          ..clear()
          ..addAll(_asStringList(data['tags']));
      });

      messenger.showSnackBar(const SnackBar(content: Text('已讀取目前狀態')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('讀取失敗：$e')));
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }

  Widget _currentCard(ColorScheme cs, String uid) {
    final preset = _currentPreset;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.surfaceContainerHighest.withValues(
                    alpha: 0.75,
                  ),
                  child: Icon(preset.icon, color: cs.onSurface),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '狀態：${preset.label}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                _pill(cs, '強度 $_intensity/5', cs.primary),
              ],
            ),
            const SizedBox(height: 12),

            // mood selection
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moods.map((m) {
                final selected = m.key == _mood;
                return ChoiceChip(
                  selected: selected,
                  label: Text(m.label),
                  avatar: Icon(m.icon, size: 18),
                  onSelected: _saving
                      ? null
                      : (v) {
                          if (v) {
                            setState(() => _mood = m.key);
                          }
                        },
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // intensity
            Row(
              children: [
                const Text('強度', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Expanded(
                  child: Slider(
                    value: _intensity.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_intensity',
                    onChanged: _saving
                        ? null
                        : (v) {
                            setState(() => _intensity = v.round().clamp(1, 5));
                          },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // note
            TextField(
              controller: _noteCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '備註（可空）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              enabled: !_saving,
            ),

            const SizedBox(height: 12),

            // tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tagPresets.map((t) {
                final selected = _tags.contains(t);
                return FilterChip(
                  selected: selected,
                  label: Text(t),
                  onSelected: _saving
                      ? null
                      : (v) {
                          setState(() {
                            if (v) {
                              _tags.add(t);
                            } else {
                              _tags.remove(t);
                            }
                          });
                        },
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _saveNow(uid: uid, alsoWriteLog: true),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? '儲存中…' : '儲存並寫入紀錄'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '提示：寫入「目前狀態」可讓 AI 對話/推薦在語氣上更貼近你的狀態。',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentLogs(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _logCol(
        uid,
      ).orderBy('createdAt', descending: true).limit(30).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('讀取失敗：${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final items = snap.data!.docs
            .map((d) => _EmotionLog.fromDoc(d))
            .toList();
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('尚無紀錄', style: TextStyle(color: Colors.grey)),
          );
        }

        return Column(
          children: items.map((log) => _logTile(uid, log)).toList(),
        );
      },
    );
  }

  Widget _logTile(String uid, _EmotionLog log) {
    final cs = Theme.of(context).colorScheme;

    final title = _labelOfMood(log.mood);
    final subtitle = [
      '強度 ${log.intensity}/5',
      if (log.tags.isNotEmpty) '標籤：${log.tags.join('、')}',
      if (log.note.trim().isNotEmpty) '備註：${log.note}',
    ].join('   ·   ');

    return Card(
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.75),
          child: Icon(_iconOfMood(log.mood)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Wrap(
          spacing: 6,
          children: [
            IconButton(
              tooltip: '套用為目前狀態',
              onPressed: _saving
                  ? null
                  : () => _applyFromLog(uid: uid, log: log),
              icon: const Icon(Icons.check_circle_outline),
            ),
            IconButton(
              tooltip: '刪除',
              onPressed: _saving ? null : () => _deleteLog(uid: uid, log: log),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(ColorScheme cs, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  // -------------------------
  // Utils
  // -------------------------
  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static List<String> _asStringList(dynamic v) {
    if (v == null) return <String>[];
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) return <String>[v.trim()];
    return <String>[];
  }

  static String _labelOfMood(String mood) {
    for (final m in _moods) {
      if (m.key == mood) {
        return m.label;
      }
    }
    return mood;
  }

  static IconData _iconOfMood(String mood) {
    for (final m in _moods) {
      if (m.key == mood) {
        return m.icon;
      }
    }
    return Icons.mood;
  }
}

// -------------------------
// Models
// -------------------------
class _MoodPreset {
  final String key;
  final String label;
  final IconData icon;
  const _MoodPreset(this.key, this.label, this.icon);
}

class _EmotionLog {
  final String id;
  final String mood;
  final int intensity;
  final String note;
  final List<String> tags;

  const _EmotionLog({
    required this.id,
    required this.mood,
    required this.intensity,
    required this.note,
    required this.tags,
  });

  factory _EmotionLog.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _EmotionLog(
      id: doc.id,
      mood: (d['mood'] ?? 'calm').toString(),
      intensity: _AIEmotionCenterPageState._asInt(
        d['intensity'],
        fallback: 3,
      ).clamp(1, 5),
      note: (d['note'] ?? '').toString(),
      tags: _AIEmotionCenterPageState._asStringList(d['tags']),
    );
  }
}
