// lib/pages/ai_voice_call_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AIVoiceCallPage extends StatefulWidget {
  const AIVoiceCallPage({super.key});

  @override
  State<AIVoiceCallPage> createState() => _AIVoiceCallPageState();
}

enum _CallState { idle, dialing, connected, ended }

enum _MsgRole { user, ai, system }

class _VoiceMsg {
  final _MsgRole role;
  final String text;
  const _VoiceMsg(this.role, this.text);

  factory _VoiceMsg.user(String t) => _VoiceMsg(_MsgRole.user, t);
  factory _VoiceMsg.ai(String t) => _VoiceMsg(_MsgRole.ai, t);
  factory _VoiceMsg.system(String t) => _VoiceMsg(_MsgRole.system, t);
}

class _AIVoiceCallPageState extends State<AIVoiceCallPage> {
  final _fs = FirebaseFirestore.instance;

  _CallState _state = _CallState.idle;

  bool _muted = false;
  bool _speaker = false;

  String _callId = '';
  DateTime? _connectedAt;
  Timer? _ticker;

  final List<_VoiceMsg> _messages = <_VoiceMsg>[];
  final ScrollController _scroll = ScrollController();

  // ✅ AI 建議快捷導頁
  final List<_QuickAction> _actions = <_QuickAction>[];

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _safeUpsertCallMeta({required String status}) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (_callId.isEmpty) {
      return;
    }

    try {
      final ref = _fs
          .collection('users')
          .doc(uid)
          .collection('ai_voice_calls')
          .doc(_callId);
      await ref.set(<String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'muted': _muted,
        'speaker': _speaker,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _safeAddMessage(_VoiceMsg msg) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (_callId.isEmpty) {
      return;
    }

    try {
      final ref = _fs
          .collection('users')
          .doc(uid)
          .collection('ai_voice_calls')
          .doc(_callId)
          .collection('messages')
          .doc();

      await ref.set(<String, dynamic>{
        'role': msg.role.name,
        'text': msg.text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // -------------------------
  // Call flow
  // -------------------------
  Future<void> _startCall() async {
    if (_state == _CallState.dialing || _state == _CallState.connected) {
      return;
    }

    setState(() {
      _state = _CallState.dialing;
      _muted = false;
      _speaker = false;
      _messages.clear();
      _actions.clear();
      _callId = _newCallId();
      _connectedAt = null;
    });

    _messages.add(_VoiceMsg.system('正在撥號…'));
    _scrollToBottomSoon();
    await _safeUpsertCallMeta(status: 'dialing');

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    if (_state != _CallState.dialing) {
      return;
    }

    setState(() {
      _state = _CallState.connected;
      _connectedAt = DateTime.now();
    });

    _messages.add(_VoiceMsg.system('✅ 已連線，開始通話'));
    _scrollToBottomSoon();
    await _safeUpsertCallMeta(status: 'connected');

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_state != _CallState.connected) {
        return;
      }
      setState(() {});
    });
  }

  Future<void> _endCall() async {
    if (_state == _CallState.idle) {
      return;
    }

    _ticker?.cancel();

    setState(() {
      _state = _CallState.ended;
    });

    _messages.add(_VoiceMsg.system('📴 通話已結束'));
    _scrollToBottomSoon();
    await _safeUpsertCallMeta(status: 'ended');

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      return;
    }
    setState(() {
      _state = _CallState.idle;
      _connectedAt = null;
    });
  }

  String _newCallId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = (ms % 9973).toString().padLeft(4, '0');
    return 'call_${ms}_$rand';
  }

  String _durationText() {
    if (_state != _CallState.connected || _connectedAt == null) {
      return '--:--';
    }
    final d = DateTime.now().difference(_connectedAt!);
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // -------------------------
  // Speak + AI reply
  // -------------------------
  Future<void> _openSpeakDialog() async {
    if (_state != _CallState.connected) {
      _snack('請先開始通話');
      return;
    }
    if (_muted) {
      _snack('目前是靜音狀態');
      return;
    }

    final textCtrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('說一句話'),
          content: TextField(
            controller: textCtrl,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '例如：我要看商品 / 我要結帳 / 我要SOS / 我想買手錶…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(textCtrl.text),
              child: const Text('送出'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    final msg = (text ?? '').trim();
    if (msg.isEmpty) {
      return;
    }

    final userMsg = _VoiceMsg.user(msg);
    setState(() {
      _messages.add(userMsg);
      _actions.clear();
    });
    _scrollToBottomSoon();
    await _safeAddMessage(userMsg);

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) {
      return;
    }
    if (_state != _CallState.connected) {
      return;
    }

    final reply = _generateAiReply(msg);
    final aiMsg = _VoiceMsg.ai(reply);

    setState(() {
      _messages.add(aiMsg);
      _actions
        ..clear()
        ..addAll(_suggestActions(msg));
    });

    _scrollToBottomSoon();
    await _safeAddMessage(aiMsg);
  }

  String _generateAiReply(String input) {
    final q = input.toLowerCase();

    if (q.contains('商品') || q.contains('手錶') || q.contains('買')) {
      return '好的，我已幫你準備商品頁入口。你可以按下方「查看商品」。';
    }
    if (q.contains('購物車') || q.contains('結帳')) {
      return '沒問題，你可以按下方快速前往購物車/結帳。';
    }
    if (q.contains('sos') || q.contains('求救') || q.contains('緊急')) {
      return '了解，你可以按下方「SOS 求救」進行一鍵求救並抓定位通知家人。';
    }

    if (q.contains('長輩') ||
        q.contains('老人') ||
        q.contains('爸') ||
        q.contains('媽')) {
      return '給長輩的話，通常重點是：大字體、清楚按鍵、定位、SOS、續航與健康量測（心率/血氧）。你最在意哪一項？';
    }
    if (q.contains('小孩') || q.contains('兒童') || q.contains('學生')) {
      return '給小孩用我會優先看：定位、SOS、防走失、安全圍籬與耐用度。你希望有通話功能嗎？';
    }

    return '我了解了。你想要的重點是哪些？（例如：SOS、定位、通話、續航、健康量測、給長輩/小孩）我可以按你的需求整理推薦。';
  }

  List<_QuickAction> _suggestActions(String input) {
    final q = input.toLowerCase();
    final actions = <_QuickAction>[];

    if (q.contains('商品') || q.contains('手錶') || q.contains('買')) {
      actions.add(
        const _QuickAction('查看商品', '/products', Icons.storefront_outlined),
      );
    }
    if (q.contains('購物車') || q.contains('結帳')) {
      actions.add(
        const _QuickAction('購物車', '/cart', Icons.shopping_cart_outlined),
      );
      actions.add(const _QuickAction('結帳', '/checkout', Icons.lock_outline));
    }
    if (q.contains('sos') || q.contains('求救') || q.contains('緊急')) {
      actions.add(
        const _QuickAction('SOS 求救', '/sos', Icons.warning_amber_rounded),
      );
    }

    if (actions.isEmpty) {
      actions.add(
        const _QuickAction('查看商品', '/products', Icons.storefront_outlined),
      );
      actions.add(
        const _QuickAction('購物車', '/cart', Icons.shopping_cart_outlined),
      );
    }
    return actions;
  }

  // -------------------------
  // UI helpers
  // -------------------------
  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _go(String route) {
    try {
      Navigator.of(context).pushNamed(route);
    } catch (_) {
      _snack('找不到路由：$route');
    }
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isConnected = _state == _CallState.connected;
    final isDialing = _state == _CallState.dialing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 語音通話'),
        actions: [
          IconButton(
            tooltip: '商品',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => _go('/products'),
          ),
          IconButton(
            tooltip: '購物車',
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => _go('/cart'),
          ),
          IconButton(
            tooltip: 'SOS',
            icon: const Icon(Icons.warning_amber_rounded),
            onPressed: () => _go('/sos'),
          ),
          IconButton(
            tooltip: '通知',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _go('/notifications'),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '開始通話',
            onPressed: (isConnected || isDialing) ? null : _startCall,
            icon: const Icon(Icons.call),
          ),
          IconButton(
            tooltip: '掛斷',
            onPressed: (isConnected || isDialing) ? _endCall : null,
            icon: const Icon(Icons.call_end),
          ),
        ],
      ),
      body: Column(
        children: [
          _statusHeader(cs),
          const Divider(height: 1),
          Expanded(child: _messageList(cs)),
          if (_actions.isNotEmpty) _quickActionsBar(cs),
          const Divider(height: 1),
          _controlsBar(cs),
        ],
      ),
    );
  }

  Widget _statusHeader(ColorScheme cs) {
    final title = _state == _CallState.idle
        ? '尚未通話'
        : _state == _CallState.dialing
        ? '撥號中…'
        : _state == _CallState.connected
        ? '通話中'
        : '通話結束';

    final subtitle = _state == _CallState.connected
        ? '通話時間 ${_durationText()}'
        : '點選電話圖示開始';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(Icons.support_agent, color: cs.primary),
              ),
              if (_state == _CallState.connected ||
                  _state == _CallState.dialing) ...[
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _state == _CallState.connected
                          ? Colors.green
                          : Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (_state == _CallState.connected) ...[
            _chip(cs, _muted ? '靜音' : '收音中'),
            const SizedBox(width: 8),
            _chip(cs, _speaker ? '擴音' : '聽筒'),
          ],
        ],
      ),
    );
  }

  Widget _chip(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _messageList(ColorScheme cs) {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          '開始通話後，你可以按「說話」輸入一句話\n我會回覆並提供快捷入口（商品/購物車/SOS）',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _bubble(cs, _messages[i]),
    );
  }

  Widget _bubble(ColorScheme cs, _VoiceMsg msg) {
    final isUser = msg.role == _MsgRole.user;

    final bg = msg.role == _MsgRole.system
        ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
        : isUser
        ? cs.primary.withValues(alpha: 0.12)
        : cs.secondary.withValues(alpha: 0.12);

    final align = msg.role == _MsgRole.system
        ? CrossAxisAlignment.center
        : isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final icon = msg.role == _MsgRole.system
        ? Icons.info_outline
        : isUser
        ? Icons.record_voice_over
        : Icons.auto_awesome;

    final label = msg.role == _MsgRole.system
        ? '系統'
        : isUser
        ? '你'
        : 'AI';

    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: msg.role == _MsgRole.system
              ? MainAxisAlignment.center
              : isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
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
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _quickActionsBar(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final a in _actions)
            FilledButton.tonalIcon(
              onPressed: () => _go(a.route),
              icon: Icon(a.icon, size: 18),
              label: Text(a.label),
            ),
        ],
      ),
    );
  }

  Widget _controlsBar(ColorScheme cs) {
    final isConnected = _state == _CallState.connected;
    final isDialing = _state == _CallState.dialing;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: isConnected ? _openSpeakDialog : null,
                icon: const Icon(Icons.mic),
                label: const Text('說話'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: _muted ? '取消靜音' : '靜音',
              onPressed: isConnected
                  ? () {
                      setState(() => _muted = !_muted);
                      _safeUpsertCallMeta(status: 'connected');
                    }
                  : null,
              icon: Icon(_muted ? Icons.mic_off : Icons.mic),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: _speaker ? '關閉擴音' : '開啟擴音',
              onPressed: isConnected
                  ? () {
                      setState(() => _speaker = !_speaker);
                      _safeUpsertCallMeta(status: 'connected');
                    }
                  : null,
              icon: Icon(_speaker ? Icons.volume_up : Icons.hearing),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '掛斷',
              onPressed: (isConnected || isDialing) ? _endCall : null,
              icon: const Icon(Icons.call_end),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.92),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final String route;
  final IconData icon;
  const _QuickAction(this.label, this.route, this.icon);
}
