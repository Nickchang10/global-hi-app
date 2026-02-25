import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ✅ ApiTestPage（API 測試工具｜最終完整版｜可編譯）
/// ------------------------------------------------------------
/// 修正：
/// - ✅ argument_type_not_assignable：_resultCard 改吃 _ApiResult?（避免你忘了加 ! 就爆）
/// - ✅ control_flow_in_finally：finally 只做收尾，不使用 return
/// - ✅ withOpacity -> withValues(alpha: ...)（deprecated_member_use）
///
/// 功能：
/// - GET / POST / PUT / DELETE
/// - 可輸入 Headers（JSON）與 Body（JSON）
/// - 可選擇帶入 Firebase ID Token（Authorization: Bearer <token>）
/// - 顯示 Status / Latency / Response Headers / Body（JSON pretty）
/// - 保留最近 History（最多 20 筆）
///
/// 注意：
/// - Web 版 Flutter 不能用 dart:io，所以使用 http 套件
class ApiTestPage extends StatefulWidget {
  const ApiTestPage({super.key});

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

enum _HttpMethod { get, post, put, delete }

class _ApiTestPageState extends State<ApiTestPage> {
  final _urlCtrl = TextEditingController();
  final _headersCtrl = TextEditingController(
    text: '{\n  "Content-Type": "application/json"\n}',
  );
  final _bodyCtrl = TextEditingController(text: '{\n  "ping": "hello"\n}');

  _HttpMethod _method = _HttpMethod.get;
  bool _useIdToken = false;

  bool _loading = false;
  _ApiResult? _result;
  String? _error;

  final List<_ApiResult> _history = <_ApiResult>[];

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = 'https://example.com/api/health'; // 改成你的 endpoint
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _headersCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // -------------------------
  // Core actions
  // -------------------------
  Future<void> _send() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _snack('請先輸入 URL');
      return;
    }

    late final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      _snack('URL 格式不正確');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    _ApiResult? res;
    String? err;

    try {
      final headers = await _buildHeaders();
      final body = _buildBodyOrNull();

      res = await _doRequest(
        uri: uri,
        method: _method,
        headers: headers,
        body: body,
      );
    } catch (e) {
      err = e.toString();
    } finally {
      // ✅ finally 只做收尾，不做 return
      if (mounted) {
        setState(() => _loading = false);
      }
    }

    if (!mounted) return;

    setState(() {
      _error = err;
      _result = res;
    });

    if (res != null) {
      setState(() {
        _history.insert(0, res!);
        if (_history.length > 20) {
          _history.removeRange(20, _history.length);
        }
      });
    }
  }

  void _clear() {
    setState(() {
      _result = null;
      _error = null;
      _history.clear();
    });
  }

  // -------------------------
  // Request helpers
  // -------------------------
  Future<Map<String, String>> _buildHeaders() async {
    final parsed = _parseHeadersJson(_headersCtrl.text);
    final headers = <String, String>{}..addAll(parsed);

    headers.putIfAbsent('Content-Type', () => 'application/json');

    if (_useIdToken) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Map<String, String> _parseHeadersJson(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return <String, String>{};

    try {
      final obj = jsonDecode(text);
      if (obj is Map) {
        final out = <String, String>{};
        for (final entry in obj.entries) {
          final k = entry.key.toString().trim();
          final v = entry.value.toString();
          if (k.isNotEmpty) out[k] = v;
        }
        return out;
      }
      throw const FormatException('Headers 必須是 JSON object');
    } catch (e) {
      throw FormatException('Headers JSON 解析失敗：$e');
    }
  }

  String? _buildBodyOrNull() {
    final raw = _bodyCtrl.text.trim();
    if (raw.isEmpty) return null;

    try {
      jsonDecode(raw);
      return raw;
    } catch (e) {
      throw FormatException('Body 不是合法 JSON：$e');
    }
  }

  Future<_ApiResult> _doRequest({
    required Uri uri,
    required _HttpMethod method,
    required Map<String, String> headers,
    required String? body,
  }) async {
    final sw = Stopwatch()..start();

    late final http.Response resp;
    switch (method) {
      case _HttpMethod.get:
        resp = await http.get(uri, headers: headers);
        break;
      case _HttpMethod.post:
        resp = await http.post(uri, headers: headers, body: body);
        break;
      case _HttpMethod.put:
        resp = await http.put(uri, headers: headers, body: body);
        break;
      case _HttpMethod.delete:
        resp = await http.delete(uri, headers: headers, body: body);
        break;
    }

    sw.stop();

    return _ApiResult(
      method: method.name.toUpperCase(),
      url: uri.toString(),
      statusCode: resp.statusCode,
      latencyMs: sw.elapsedMilliseconds,
      responseHeaders: resp.headers,
      responseBody: resp.body,
      requestedAt: DateTime.now(),
    );
  }

  // -------------------------
  // UI helpers
  // -------------------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _prettyBody(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    try {
      final obj = jsonDecode(t);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(ColorScheme cs, int? code) {
    if (code == null) return cs.onSurfaceVariant;
    if (code >= 200 && code < 300) return Colors.green;
    if (code >= 400 && code < 500) return Colors.orange;
    if (code >= 500) return Colors.red;
    return cs.onSurfaceVariant;
  }

  // -------------------------
  // Build
  // -------------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 測試'),
        actions: [
          IconButton(
            tooltip: '清除結果/歷史',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          _topForm(cs),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                if (_error != null) _errorCard(cs, _error!),
                // ✅ 這裡直接丟 nullable 也不會爆
                _resultCard(cs, _result),
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _historyCard(cs),
                ],
                if (_result == null && _error == null && _history.isEmpty)
                  _emptyHint(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topForm(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              DropdownButton<_HttpMethod>(
                value: _method,
                items: const [
                  DropdownMenuItem(value: _HttpMethod.get, child: Text('GET')),
                  DropdownMenuItem(
                    value: _HttpMethod.post,
                    child: Text('POST'),
                  ),
                  DropdownMenuItem(value: _HttpMethod.put, child: Text('PUT')),
                  DropdownMenuItem(
                    value: _HttpMethod.delete,
                    child: Text('DELETE'),
                  ),
                ],
                onChanged: _loading
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _method = v);
                      },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _loading ? null : _send,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('送出'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _headersCtrl,
                  enabled: !_loading,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Headers (JSON Object)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _bodyCtrl,
                  enabled: !_loading,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Body (JSON)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Switch(
                value: _useIdToken,
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _useIdToken = v),
              ),
              const SizedBox(width: 6),
              const Text('帶入 Firebase ID Token（Authorization Bearer）'),
              const Spacer(),
              Text(
                FirebaseAuth.instance.currentUser == null ? '未登入' : '已登入',
                style: TextStyle(
                  color: FirebaseAuth.instance.currentUser == null
                      ? cs.onSurfaceVariant
                      : Colors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorCard(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 改成吃 nullable：避免你忘了加 ! 導致 argument_type_not_assignable
  Widget _resultCard(ColorScheme cs, _ApiResult? r) {
    if (r == null) {
      return const SizedBox.shrink();
    }

    final pretty = _prettyBody(r.responseBody);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    r.method,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Status: ${r.statusCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _statusColor(cs, r.statusCode),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Latency: ${r.latencyMs} ms',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(r.requestedAt),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _kvBox(
              cs,
              'Response Headers',
              const JsonEncoder.withIndent('  ').convert(r.responseHeaders),
            ),
            const SizedBox(height: 10),
            _kvBox(cs, 'Response Body', pretty.isEmpty ? '(empty)' : pretty),
          ],
        ),
      ),
    );
  }

  Widget _kvBox(ColorScheme cs, String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SelectableText(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.30),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'History（最近 20 筆）',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ..._history.map((h) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _result = h;
                    _error = null;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        h.method,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          h.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${h.statusCode}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _statusColor(cs, h.statusCode),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${h.latencyMs}ms',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Center(
        child: Text(
          '輸入 URL 後按「送出」即可測試 API\nHeaders/Body 需為 JSON（Body 可留空）',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}

// -------------------------
// Models
// -------------------------
class _ApiResult {
  final String method;
  final String url;
  final int statusCode;
  final int latencyMs;
  final Map<String, String> responseHeaders;
  final String responseBody;
  final DateTime requestedAt;

  const _ApiResult({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.latencyMs,
    required this.responseHeaders,
    required this.responseBody,
    required this.requestedAt,
  });
}
