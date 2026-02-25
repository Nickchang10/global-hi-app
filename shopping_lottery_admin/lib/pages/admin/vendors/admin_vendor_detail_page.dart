import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ✅ AdminVendorDetailPage（正式版｜可編譯｜相容 vendorId / id / vendorUid）
/// ------------------------------------------------------------
/// Firestore:
/// vendors/{vendorId}
/// ------------------------------------------------------------
class AdminVendorDetailPage extends StatefulWidget {
  /// ✅ 向下相容：你專案可能以前用 id 或 vendorUid
  const AdminVendorDetailPage({
    super.key,
    this.vendorId,
    this.id,
    this.vendorUid,
  });

  final String? vendorId;
  final String? id;
  final String? vendorUid;

  @override
  State<AdminVendorDetailPage> createState() => _AdminVendorDetailPageState();
}

class _AdminVendorDetailPageState extends State<AdminVendorDetailPage> {
  final _db = FirebaseFirestore.instance;

  late final String _vid;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('vendors').doc(_vid);

  @override
  void initState() {
    super.initState();
    final resolved = (widget.vendorId ?? widget.id ?? widget.vendorUid)?.trim();
    _vid = (resolved == null || resolved.isEmpty) ? '' : resolved;
  }

  @override
  Widget build(BuildContext context) {
    if (_vid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendor 詳情')),
        body: const Center(
          child: Text(
            '缺少 vendorId（請從列表帶入 vendorId / id / vendorUid）',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor 詳情'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(message: '讀取 vendor 失敗：${snap.error}');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snap.data!;
          if (!doc.exists) {
            return Center(
              child: Text(
                '找不到 vendors/$_vid',
                style: TextStyle(color: cs.error),
              ),
            );
          }

          final v = doc.data() ?? <String, dynamic>{};

          String s(String k) => (v[k] ?? '').toString().trim();
          bool b(String k) => v[k] == true;

          final name = s('name').isEmpty ? '(未命名商家)' : s('name');
          final brand = s('brandName').isNotEmpty ? s('brandName') : s('brand');
          final email = s('email');
          final phone = s('phone');
          final contact = s('contactName').isNotEmpty
              ? s('contactName')
              : s('contact');
          final address = s('address');
          final taxId = s('taxId').isNotEmpty ? s('taxId') : s('vat');
          final note = s('note').isNotEmpty ? s('note') : s('notes');

          final active = b('active');
          final verified = b('verified');
          final status = s('status').isEmpty ? 'pending' : s('status');
          final rejectReason = s('rejectReason');

          Color statusColor() {
            switch (status) {
              case 'approved':
                return Colors.green;
              case 'rejected':
                return cs.error;
              default:
                return Colors.orange;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0.6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor().withValues(alpha: 0.12),
                        child: Icon(Icons.store, color: statusColor()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _Chip(icon: Icons.key, text: _vid),
                                _Chip(
                                  icon: Icons.flag,
                                  text: status,
                                  iconColor: statusColor(),
                                ),
                                _Chip(
                                  icon: active
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  text: active ? 'active' : 'inactive',
                                  iconColor: active ? Colors.green : cs.error,
                                ),
                                _Chip(
                                  icon: verified
                                      ? Icons.verified
                                      : Icons.help_outline,
                                  text: verified ? 'verified' : 'unverified',
                                  iconColor: verified
                                      ? cs.primary
                                      : Colors.grey,
                                ),
                              ],
                            ),
                            if (brand.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('品牌：$brand'),
                            ],
                            if (contact.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('聯絡：$contact'),
                            ],
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Email：$email'),
                            ],
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('電話：$phone'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '快速操作',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),

                      /// ✅ 修正：async gap 後不再用 context
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: const Text('啟用/停用此商家'),
                        value: active,
                        onChanged: (nv) async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _ref.set({
                              'active': nv,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('已更新 active=$nv')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('更新失敗：$e')),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 10),

                      /// ✅ 修正：async gap 後不再用 context
                      DropdownButtonFormField<String>(
                        initialValue: status, // ✅ 避免新版本 deprecated value
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '審核狀態 status',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('pending'),
                          ),
                          DropdownMenuItem(
                            value: 'approved',
                            child: Text('approved'),
                          ),
                          DropdownMenuItem(
                            value: 'rejected',
                            child: Text('rejected'),
                          ),
                        ],
                        onChanged: (v) async {
                          final next = (v ?? '').trim();
                          if (next.isEmpty) return;

                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _ref.set({
                              'status': next,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('已更新 status=$next')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('更新失敗：$e')),
                            );
                          }
                        },
                      ),

                      if (status == 'rejected' &&
                          rejectReason.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '拒絕原因：$rejectReason',
                          style: TextStyle(color: cs.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '資料欄位',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      _kv('address', address),
                      _kv('taxId/vat', taxId),
                      _kv('note/notes', note),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    final val = v.trim().isEmpty ? '-' : v.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(val)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: iconColor),
      label: Text(text),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
