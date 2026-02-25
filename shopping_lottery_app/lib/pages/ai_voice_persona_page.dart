import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ AIVoicePersonaPage（AI 語音人格設定｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正/強化：
/// - ✅ if 單行語句一律加大括號（解 curly_braces_in_flow_control_structures）
/// - ✅ withOpacity -> withValues(alpha: ...)（解 deprecated_member_use）
///
/// 功能：
/// - 內建多組「語音人格」
/// - 可「試說」：輸入一句話，回傳不同人格風格的模擬回覆（不依賴 TTS / STT）
/// - 可「套用」：
///   - 若已登入：寫入 Firestore：users/{uid}/ai_settings/voice 內的 voicePersonaId
///   - 若未登入：只存在本地 state（不噴錯）
///
/// 你其他 AI 頁面要讀人格：
/// - 讀取同一路徑 users/{uid}/ai_settings/voice 的 voicePersonaId
class AIVoicePersonaPage extends StatefulWidget {
  const AIVoicePersonaPage({super.key});

  @override
  State<AIVoicePersonaPage> createState() => _AIVoicePersonaPageState();
}

class _AIVoicePersonaPageState extends State<AIVoicePersonaPage> {
  final _fs = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  late final List<_VoicePersona> _personas = _builtInPersonas();
  String _selectedId = 'friendly';

  final TextEditingController _testCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadSavedPersona();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _testCtrl.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _voiceSettingRef(String uid) {
    return _fs
        .collection('users')
        .doc(uid)
        .collection('ai_settings')
        .doc('voice');
  }

  Future<void> _loadSavedPersona() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      // 未登入：用預設
      setState(() {
        _loading = false;
        _selectedId = _selectedId; // keep default
      });
      return;
    }

    try {
      final doc = await _voiceSettingRef(uid).get();
      final data = doc.data();
      final saved = (data?['voicePersonaId'] ?? '').toString().trim();
      if (saved.isNotEmpty && _personas.any((p) => p.id == saved)) {
        _selectedId = saved;
      }
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '讀取設定失敗（可忽略）：$e';
      });
    }
  }

  Future<void> _savePersona() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      _snack('尚未登入：已套用在本次 App 使用（未寫入雲端）');
      return;
    }

    try {
      await _voiceSettingRef(uid).set(<String, dynamic>{
        'voicePersonaId': _selectedId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }
      _snack('已套用並同步雲端設定');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _snack('寫入雲端失敗（可忽略）：$e');
    }
  }

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  _VoicePersona get _selectedPersona {
    return _personas.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => _personas.first,
    );
  }

  Future<void> _openTryDialog() async {
    final cs = Theme.of(context).colorScheme;

    final input = _testCtrl.text.trim();
    if (input.isEmpty) {
      _snack('請先輸入一句話再試說');
      return;
    }

    final persona = _selectedPersona;
    final reply = _simulateReply(persona, input);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(persona.icon, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('試說：${persona.name}')),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bubble(
                  cs,
                  label: '你',
                  icon: Icons.record_voice_over,
                  bg: cs.primary.withValues(alpha: 0.10),
                  text: input,
                ),
                const SizedBox(height: 12),
                _bubble(
                  cs,
                  label: 'AI（${persona.name}）',
                  icon: Icons.auto_awesome,
                  bg: cs.secondary.withValues(alpha: 0.10),
                  text: reply,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  Widget _bubble(
    ColorScheme cs, {
    required String label,
    required IconData icon,
    required Color bg,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _simulateReply(_VoicePersona persona, String input) {
    final q = input.trim();
    final lower = q.toLowerCase();

    // 讓人格差異明顯一些（純規則示範）
    switch (persona.id) {
      case 'professional':
        if (lower.contains('sos') ||
            lower.contains('求救') ||
            lower.contains('緊急')) {
          return '了解。若需求為 SOS／緊急求助，建議優先確認：一鍵求救流程、通知對象、定位精度與通報延遲。請問使用者族群是長輩或兒童？';
        }
        return '收到。請你列出 2~3 個最重要條件（例如：定位、通話、續航、健康量測），我會依條件整理建議選項。';

      case 'gentle':
        if (lower.contains('長輩') ||
            lower.contains('老人') ||
            lower.contains('爸') ||
            lower.contains('媽')) {
          return '我懂你的擔心💛 給長輩用的話，我會先看「一鍵求救、定位、續航、字體與操作」；你最在意哪一項呢？';
        }
        return '沒問題～你慢慢說，我會陪你一起整理需求。你想要的重點是 SOS、定位、通話，還是續航呢？';

      case 'cheerful':
        if (lower.contains('小孩') ||
            lower.contains('兒童') ||
            lower.contains('學生')) {
          return 'OK！給小朋友的話我會優先看「定位＋安全圍籬＋SOS＋耐用」🔥 你希望可以通話嗎？';
        }
        return '收到！把你最想要的功能丟給我：SOS？定位？通話？預算？我幫你快速配對～';

      case 'sales':
        if (lower.contains('預算') ||
            lower.contains('便宜') ||
            lower.contains('多少錢')) {
          return '當然可以～你預算大概落在哪裡？2000 / 3000 / 5000？我可以直接縮小到最划算的幾款給你。';
        }
        return '了解！我先抓你最在意的 1~2 個點（SOS/定位/通話/續航），再幫你挑 CP 值最高的組合～你最在意哪個？';

      case 'friendly':
      default:
        if (lower.contains('定位') ||
            lower.contains('gps') ||
            lower.contains('追蹤')) {
          return '想要定位的話，我建議挑有即時定位＋安全圍籬的款式～你希望主要給長輩用還是給小孩用？';
        }
        if (lower.contains('sos') ||
            lower.contains('求救') ||
            lower.contains('緊急')) {
          return '如果你需要 SOS，我會優先找「一鍵求救＋通知家人」的款式～你預算大概多少？';
        }
        return '我收到你的需求了！你最想要的是哪幾個功能：SOS、定位、通話、續航或健康量測？';
    }
  }

  List<_VoicePersona> _builtInPersonas() {
    return const [
      _VoicePersona(
        id: 'friendly',
        name: '親切日常',
        tagline: '溫和、清楚、好理解',
        icon: Icons.sentiment_satisfied_alt,
      ),
      _VoicePersona(
        id: 'professional',
        name: '專業顧問',
        tagline: '條列、精準、偏產品規格導向',
        icon: Icons.workspace_premium,
      ),
      _VoicePersona(
        id: 'gentle',
        name: '溫柔陪伴',
        tagline: '共感、安撫、適合照護情境',
        icon: Icons.favorite,
      ),
      _VoicePersona(
        id: 'cheerful',
        name: '活力夥伴',
        tagline: '節奏快、鼓舞、適合年輕族群',
        icon: Icons.bolt,
      ),
      _VoicePersona(
        id: 'sales',
        name: '超會導購',
        tagline: '主動追問關鍵條件、幫你縮小選項',
        icon: Icons.shopping_bag,
      ),
    ];
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 語音人格'),
        actions: [
          IconButton(
            tooltip: '重新載入',
            onPressed: _loadSavedPersona,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _intro(cs),
                if (_error != null) _warn(cs, _error!),
                _tryInput(cs),
                const Divider(height: 1),
                Expanded(child: _personaList(cs)),
                const Divider(height: 1),
                _bottomBar(cs),
              ],
            ),
    );
  }

  Widget _intro(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(Icons.graphic_eq, color: cs.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '在這裡選擇 AI 的「語音人格」。\n'
                  '你可以先輸入一句話按「試說」，再按「套用」保存設定。',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _warn(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.brown)),
      ),
    );
  }

  Widget _tryInput(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _testCtrl,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 220), () {
                  if (!mounted) {
                    return;
                  }
                  setState(() {});
                });
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mic_none),
                hintText: '輸入一句話試試看（例如：我要 SOS + 定位）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _testCtrl.text.trim().isEmpty ? null : _openTryDialog,
            icon: const Icon(Icons.play_arrow),
            label: const Text('試說'),
          ),
        ],
      ),
    );
  }

  Widget _personaList(ColorScheme cs) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: _personas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = _personas[i];
        final selected = p.id == _selectedId;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _selectedId = p.id);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary.withValues(alpha: 0.08)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.55)
                    : cs.outlineVariant.withValues(alpha: 0.45),
                width: selected ? 1.2 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.surface.withValues(alpha: 0.85),
                  child: Icon(p.icon, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.tagline,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (selected)
                  Icon(Icons.check_circle, color: cs.primary)
                else
                  Icon(Icons.circle_outlined, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _savePersona,
                icon: const Icon(Icons.save),
                label: Text('套用：${_selectedPersona.name}'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: '清除輸入',
              onPressed: () {
                _testCtrl.clear();
                if (!mounted) {
                  return;
                }
                setState(() {});
              },
              icon: const Icon(Icons.clear),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------
// Models
// -------------------------
class _VoicePersona {
  final String id;
  final String name;
  final String tagline;
  final IconData icon;

  const _VoicePersona({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
  });
}
