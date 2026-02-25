import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// AdminPaymentsPage（正式版｜完整版｜可直接編譯）
///
/// - 修正：unused_field（_role 會被 UI/權限邏輯使用）
/// - 修正：curly_braces_in_flow_control_structures（if 必須加 {}）
/// - 順便修正：Dialog pop 改用 dialogCtx（避免 use_build_context_synchronously）
/// - 順便修正：withOpacity deprecated -> withValues(alpha: ...)
///
/// - 兩個分頁：
///   1) 支付供應商（payment_providers）
///   2) 支付交易（payment_transactions）
class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key, this.role});

  /// 可選：由外層 AdminGate/Session 傳入角色
  /// - 'super_admin' / 'superadmin'：可看/改 secretKey
  /// - 其他：只能看一般設定
  final String? role;

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage>
    with SingleTickerProviderStateMixin {
  late final String _role = (widget.role ?? 'admin').trim();

  bool get _isSuperAdmin {
    final r = _role.toLowerCase();
    return r == 'super_admin' ||
        r == 'superadmin' ||
        r == 'root' ||
        r == 'owner';
  }

  late final TabController _tab;

  CollectionReference<Map<String, dynamic>> get _providersRef =>
      FirebaseFirestore.instance.collection('payment_providers');

  CollectionReference<Map<String, dynamic>> get _txRef =>
      FirebaseFirestore.instance.collection('payment_transactions');

  bool _busy = false;
  final _txSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _txSearchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  String _fmtTs(dynamic v) {
    DateTime? dt;
    if (v is Timestamp) dt = v.toDate();
    if (v is DateTime) dt = v;
    if (dt == null) return '-';
    final l = dt.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openProviderEditor({
    String? id,
    Map<String, dynamic>? initial,
  }) async {
    final res = await showModalBottomSheet<_ProviderEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProviderEditorSheet(
        providerId: id,
        initial: initial,
        canEditSecret: _isSuperAdmin,
      ),
    );
    if (res == null) return;

    setState(() => _busy = true);
    try {
      final payload = <String, dynamic>{
        ...res.payload,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (id == null) {
        await _providersRef.add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _snack('已新增支付供應商');
      } else {
        await _providersRef.doc(id).set(payload, SetOptions(merge: true));
        _snack('已更新支付供應商');
      }
    } catch (e) {
      _snack('保存失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProvider(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('刪除支付供應商'),
        content: Text('確定要刪除 provider=$id 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _providersRef.doc(id).delete();
      _snack('已刪除供應商');
    } catch (e) {
      _snack('刪除失敗：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleProvider(String id, bool enabled) async {
    try {
      await _providersRef.doc(id).set({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _snack('更新啟用狀態失敗：$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleChip = Chip(
      avatar: Icon(_isSuperAdmin ? Icons.verified : Icons.shield, size: 16),
      label: Text(_isSuperAdmin ? 'Role: Super Admin' : 'Role: $_role'),
      visualDensity: VisualDensity.compact,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('支付管理'),
        actions: [
          roleChip,
          const SizedBox(width: 8),
          if (_tab.index == 0)
            IconButton(
              tooltip: '新增供應商',
              onPressed: _busy ? null : () => _openProviderEditor(),
              icon: const Icon(Icons.add),
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.credit_card), text: '供應商'),
            Tab(icon: Icon(Icons.receipt_long), text: '交易'),
          ],
          onTap: (_) => setState(() {}),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_providersTab(), _transactionsTab()],
      ),
    );
  }

  Widget _providersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _providersRef.orderBy('sort').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              '讀取失敗：${snap.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('尚未建立支付供應商', style: TextStyle(color: Colors.grey[700])),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i];
            final m = d.data();

            final name = (m['name'] ?? '').toString().trim();
            final enabled = m['enabled'] != false;
            final merchantId = (m['merchantId'] ?? '').toString().trim();
            final webhookUrl = (m['webhookUrl'] ?? '').toString().trim();
            final updatedAt = _fmtTs(m['updatedAt']);

            final publicKey = (m['publicKey'] ?? '').toString().trim();
            final secretKey = (m['secretKey'] ?? '').toString().trim();

            return Card(
              elevation: 0.7,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  child: Icon(enabled ? Icons.check_circle : Icons.block),
                ),
                title: Text(
                  name.isEmpty ? '(未命名供應商)' : name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.key, size: 16),
                          label: Text('id: ${d.id}'),
                        ),
                        if (merchantId.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.badge, size: 16),
                            label: Text('merchant: $merchantId'),
                          ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.update, size: 16),
                          label: Text('updated: $updatedAt'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (publicKey.isNotEmpty)
                      Text(
                        'publicKey: ${_mask(publicKey)}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    if (_isSuperAdmin && secretKey.isNotEmpty)
                      Text(
                        'secretKey: ${_mask(secretKey)}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    if (!_isSuperAdmin && secretKey.isNotEmpty)
                      Text(
                        'secretKey: (僅 Super Admin 可見)',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    if (webhookUrl.isNotEmpty)
                      Text(
                        'webhook: $webhookUrl',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                  ],
                ),
                trailing: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Switch(
                        value: enabled,
                        onChanged: _busy
                            ? null
                            : (v) => _toggleProvider(d.id, v),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: '編輯',
                            onPressed: _busy
                                ? null
                                : () =>
                                      _openProviderEditor(id: d.id, initial: m),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: '刪除',
                            onPressed: _busy
                                ? null
                                : () => _deleteProvider(d.id),
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                onTap: _busy
                    ? null
                    : () => _openProviderEditor(id: d.id, initial: m),
              ),
            );
          },
        );
      },
    );
  }

  Widget _transactionsTab() {
    final keyword = _txSearchCtrl.text.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: TextField(
            controller: _txSearchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜尋：orderId / status / providerId / txId',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                tooltip: '清除',
                onPressed: () {
                  _txSearchCtrl.clear();
                  FocusScope.of(context).unfocus();
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _txRef
                .orderBy('createdAt', descending: true)
                .limit(200)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text(
                    '讀取失敗：${snap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              final rows = docs.where((d) {
                if (keyword.isEmpty) return true;
                final m = d.data();
                final orderId = (m['orderId'] ?? '').toString().toLowerCase();
                final status = (m['status'] ?? '').toString().toLowerCase();
                final providerId = (m['providerId'] ?? '')
                    .toString()
                    .toLowerCase();
                return d.id.toLowerCase().contains(keyword) ||
                    orderId.contains(keyword) ||
                    status.contains(keyword) ||
                    providerId.contains(keyword);
              }).toList();

              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    '沒有交易資料',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = rows[i];
                  final m = d.data();

                  final orderId = (m['orderId'] ?? '').toString().trim();
                  final providerId = (m['providerId'] ?? '').toString().trim();
                  final status = (m['status'] ?? 'unknown').toString().trim();
                  final amount = m['amount'];
                  final currency = (m['currency'] ?? '').toString().trim();
                  final message = (m['message'] ?? '').toString().trim();
                  final createdAt = _fmtTs(m['createdAt']);

                  return Card(
                    elevation: 0.6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(_statusIcon(status))),
                      title: Text(
                        orderId.isEmpty ? 'Order: (未填)' : 'Order: $orderId',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.key, size: 16),
                                label: Text('tx: ${d.id}'),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.store, size: 16),
                                label: Text(
                                  'provider: ${providerId.isEmpty ? '-' : providerId}',
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.flag, size: 16),
                                label: Text(status),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.payments, size: 16),
                                label: Text(
                                  '${amount ?? '-'} ${currency.isEmpty ? '' : currency}',
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.schedule, size: 16),
                                label: Text(createdAt),
                              ),
                            ],
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              message,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
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
    );
  }
}

class _ProviderEditResult {
  const _ProviderEditResult(this.payload);
  final Map<String, dynamic> payload;
}

class _ProviderEditorSheet extends StatefulWidget {
  const _ProviderEditorSheet({
    required this.providerId,
    required this.initial,
    required this.canEditSecret,
  });

  final String? providerId;
  final Map<String, dynamic>? initial;
  final bool canEditSecret;

  @override
  State<_ProviderEditorSheet> createState() => _ProviderEditorSheetState();
}

class _ProviderEditorSheetState extends State<_ProviderEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _merchantId;
  late final TextEditingController _publicKey;
  late final TextEditingController _secretKey;
  late final TextEditingController _webhookUrl;
  late final TextEditingController _note;
  late final TextEditingController _sort;

  bool _enabled = true;
  bool _showSecret = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? <String, dynamic>{};

    _name = TextEditingController(text: (m['name'] ?? '').toString());
    _merchantId = TextEditingController(
      text: (m['merchantId'] ?? '').toString(),
    );
    _publicKey = TextEditingController(text: (m['publicKey'] ?? '').toString());
    _secretKey = TextEditingController(text: (m['secretKey'] ?? '').toString());
    _webhookUrl = TextEditingController(
      text: (m['webhookUrl'] ?? '').toString(),
    );
    _note = TextEditingController(text: (m['note'] ?? '').toString());
    _sort = TextEditingController(text: (m['sort'] ?? 0).toString());

    _enabled = m['enabled'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    _merchantId.dispose();
    _publicKey.dispose();
    _secretKey.dispose();
    _webhookUrl.dispose();
    _note.dispose();
    _sort.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final sort = int.tryParse(_sort.text.trim()) ?? 0;

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'enabled': _enabled,
      'sort': sort,
      'merchantId': _merchantId.text.trim(),
      'publicKey': _publicKey.text.trim(),
      'webhookUrl': _webhookUrl.text.trim(),
      'note': _note.text.trim(),
    };

    if (widget.canEditSecret) {
      payload['secretKey'] = _secretKey.text.trim();
    }

    Navigator.pop(context, _ProviderEditResult(payload));
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.providerId == null;
    final pad = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: pad.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreate ? '新增供應商' : '編輯供應商',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isCreate) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ID: ${widget.providerId}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 14),

                _tf(_name, '名稱（必填）', required: true),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: _tf(_merchantId, 'Merchant ID')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tf(
                        _sort,
                        'Sort（數字）',
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _tf(_publicKey, 'Public Key'),
                const SizedBox(height: 10),

                if (widget.canEditSecret) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _secretKey,
                          obscureText: !_showSecret,
                          decoration: const InputDecoration(
                            labelText: 'Secret Key（Super Admin）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: _showSecret ? '隱藏' : '顯示',
                        onPressed: () {
                          setState(() => _showSecret = !_showSecret);
                        },
                        icon: Icon(
                          _showSecret ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'Secret Key：僅 Super Admin 可查看/修改',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                _tf(_webhookUrl, 'Webhook URL'),
                const SizedBox(height: 10),

                _tf(_note, '備註', maxLines: 3),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用 enabled'),
                  value: _enabled,
                  onChanged: (v) {
                    setState(() => _enabled = v);
                  },
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tf(
    TextEditingController c,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => (v ?? '').trim().isEmpty ? '必填' : null
          : null,
    );
  }
}

String _mask(String s) {
  if (s.isEmpty) return '';
  if (s.length <= 8) return '****';
  return '${s.substring(0, 4)}****${s.substring(s.length - 4)}';
}

IconData _statusIcon(String status) {
  final s = status.toLowerCase();
  if (s.contains('success') || s == 'paid') return Icons.check_circle;
  if (s.contains('fail') || s.contains('error')) return Icons.cancel;
  if (s.contains('refund')) return Icons.currency_exchange;
  if (s.contains('pending') || s.contains('processing')) return Icons.timelapse;
  return Icons.help_outline;
}
