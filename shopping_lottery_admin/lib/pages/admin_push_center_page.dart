import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPushCenterPage extends StatefulWidget {
  const AdminPushCenterPage({super.key, this.standalone = true});

  /// standalone=true：自己帶 Scaffold + AppBar
  /// standalone=false：給外層（例如 AdminShell）包 Scaffold
  final bool standalone;

  @override
  State<AdminPushCenterPage> createState() => _AdminPushCenterPageState();
}

enum _TargetMode { singleUid, allUsers, byRole }

class _AdminPushCenterPageState extends State<AdminPushCenterPage> {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _deepLinkCtrl = TextEditingController();
  final TextEditingController _routeCtrl = TextEditingController();
  final TextEditingController _singleUidCtrl = TextEditingController();

  bool _useRootNotificationsCollection = false;
  _TargetMode _targetMode = _TargetMode.allUsers;

  String _type = 'general';
  String _roleFilter = 'user';

  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _deepLinkCtrl.dispose();
    _routeCtrl.dispose();
    _singleUidCtrl.dispose();
    super.dispose();
  }

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    try {
      final doc = await _fs.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      final role = (data['role'] ?? 'user').toString().toLowerCase().trim();
      return role == 'admin' || role == 'super_admin';
    } catch (_) {
      // 若暫時沒有 role 欄位：先放行避免卡死
      return true;
    }
  }

  CollectionReference<Map<String, dynamic>> _rootNotificationsCol() =>
      _fs.collection('notifications');

  CollectionReference<Map<String, dynamic>> _userNotificationsCol(String uid) =>
      _fs.collection('users').doc(uid).collection('notifications');

  Future<void> _writeNotificationToUid({
    required String uid,
    required Map<String, dynamic> payload,
  }) async {
    if (_useRootNotificationsCollection) {
      await _rootNotificationsCol().add(<String, dynamic>{
        ...payload,
        'uid': uid,
      });
    } else {
      await _userNotificationsCol(uid).add(payload);
    }
  }

  Future<int> _writeNotificationToManyUids({
    required List<String> uids,
    required Map<String, dynamic> payload,
  }) async {
    int wrote = 0;
    final now = FieldValue.serverTimestamp();

    int i = 0;
    while (i < uids.length) {
      final slice = uids.skip(i).take(450).toList();
      final batch = _fs.batch();

      for (final uid in slice) {
        if (_useRootNotificationsCollection) {
          final ref = _rootNotificationsCol().doc();
          batch.set(ref, <String, dynamic>{
            ...payload,
            'uid': uid,
            'createdAt': now,
          });
        } else {
          final ref = _userNotificationsCol(uid).doc();
          batch.set(ref, <String, dynamic>{...payload, 'createdAt': now});
        }
      }

      await batch.commit();
      wrote += slice.length;
      i += slice.length;
    }

    return wrote;
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) {
      return '此欄位必填';
    }
    return null;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long;
      case 'promo':
        return Icons.local_offer;
      case 'system':
        return Icons.campaign;
      case 'sos':
        return Icons.sos;
      case 'support_task':
        return Icons.support_agent;
      default:
        return Icons.notifications_none;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'order':
        return '訂單';
      case 'promo':
        return '促銷';
      case 'system':
        return '系統';
      case 'sos':
        return 'SOS';
      case 'support_task':
        return '客服任務';
      case 'general':
        return '一般';
      default:
        return type;
    }
  }

  String _targetLabel() {
    switch (_targetMode) {
      case _TargetMode.allUsers:
        return '全部會員';
      case _TargetMode.byRole:
        return '依角色（$_roleFilter）';
      case _TargetMode.singleUid:
        return '指定 UID';
    }
  }

  Future<void> _send() async {
    if (_sending) {
      return;
    }

    // ✅ async gap 前先取 messenger
    final messenger = ScaffoldMessenger.of(context);

    final okForm = _formKey.currentState?.validate() ?? false;
    if (!okForm) {
      return;
    }

    if (_targetMode == _TargetMode.singleUid) {
      final uid = _singleUidCtrl.text.trim();
      if (uid.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('請輸入目標 UID')));
        return;
      }
    }

    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final deepLink = _deepLinkCtrl.text.trim();
    final route = _routeCtrl.text.trim();

    final user = FirebaseAuth.instance.currentUser;
    final fromUid = user?.uid ?? '';

    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'type': _type,
      'read': false,
      if (deepLink.isNotEmpty) 'deepLink': deepLink,
      if (route.isNotEmpty) 'route': route,
      'source': 'admin_push',
      'fromUid': fromUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final bodyPreview = body.length > 80 ? '${body.substring(0, 80)}…' : body;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '確認送出',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('類型：${_typeLabel(_type)}'),
              const SizedBox(height: 6),
              Text('標題：$title'),
              const SizedBox(height: 6),
              Text('內容：$bodyPreview'),
              const Divider(height: 20),
              Text(
                '寫入位置：${_useRootNotificationsCollection ? 'root notifications' : 'users/{uid}/notifications'}',
              ),
              const SizedBox(height: 6),
              Text('目標：${_targetLabel()}'),
              if (_targetMode == _TargetMode.singleUid) ...[
                const SizedBox(height: 6),
                Text('UID：${_singleUidCtrl.text.trim()}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('送出'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() => _sending = true);

    try {
      int wrote = 0;

      if (_targetMode == _TargetMode.singleUid) {
        final uid = _singleUidCtrl.text.trim();
        await _writeNotificationToUid(
          uid: uid,
          payload: <String, dynamic>{
            ...payload,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
        wrote = 1;
      } else {
        DocumentSnapshot<Map<String, dynamic>>? last;
        const pageSize = 400;

        while (true) {
          Query<Map<String, dynamic>> q = _fs
              .collection('users')
              .limit(pageSize);

          if (_targetMode == _TargetMode.byRole) {
            q = _fs
                .collection('users')
                .where('role', isEqualTo: _roleFilter)
                .limit(pageSize);
          }

          if (last != null) {
            q = q.startAfterDocument(last);
          }

          final snap = await q.get();
          if (snap.docs.isEmpty) {
            break;
          }

          last = snap.docs.last;
          final uids = snap.docs.map((d) => d.id).toList();

          wrote += await _writeNotificationToManyUids(
            uids: uids,
            payload: payload,
          );
        }
      }

      if (!mounted) {
        return;
      }
      setState(() => _sending = false);

      messenger.showSnackBar(SnackBar(content: Text('✅ 已送出 $wrote 則通知')));

      _bodyCtrl.clear();
      _deepLinkCtrl.clear();
      _routeCtrl.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text('送出失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('請先登入'));
    }

    final content = FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, snap) {
        final ok = snap.data ?? false;

        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!ok) {
          return const Center(child: Text('你沒有權限（admin）'));
        }

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('寫入位置'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _useRootNotificationsCollection,
                onChanged: _sending
                    ? null
                    : (v) {
                        setState(() => _useRootNotificationsCollection = v);
                      },
                title: const Text('使用 root notifications'),
                subtitle: const Text(
                  '開啟：寫入 notifications（需 uid 欄位）\n'
                  '關閉：寫入 users/{uid}/notifications（建議）',
                ),
              ),
              const Divider(height: 24),
              _sectionTitle('目標對象'),
              _targetSelector(),
              const SizedBox(height: 10),

              if (_targetMode == _TargetMode.singleUid) ...[
                TextFormField(
                  controller: _singleUidCtrl,
                  decoration: const InputDecoration(
                    labelText: '目標 UID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (_targetMode == _TargetMode.singleUid) {
                      return _required(v);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
              ],

              if (_targetMode == _TargetMode.byRole) ...[
                DropdownButtonFormField<String>(
                  initialValue: _roleFilter,
                  decoration: const InputDecoration(
                    labelText: '角色（users.role）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('user')),
                    DropdownMenuItem(value: 'vip', child: Text('vip')),
                    DropdownMenuItem(value: 'vendor', child: Text('vendor')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(
                      value: 'super_admin',
                      child: Text('super_admin'),
                    ),
                  ],
                  onChanged: _sending
                      ? null
                      : (v) {
                          if (v == null) {
                            return;
                          }
                          setState(() => _roleFilter = v);
                        },
                ),
                const SizedBox(height: 10),
              ],

              const Divider(height: 24),
              _sectionTitle('通知內容'),

              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: '類型',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('一般 general')),
                  DropdownMenuItem(value: 'promo', child: Text('促銷 promo')),
                  DropdownMenuItem(value: 'system', child: Text('系統 system')),
                  DropdownMenuItem(value: 'order', child: Text('訂單 order')),
                  DropdownMenuItem(value: 'sos', child: Text('SOS sos')),
                  DropdownMenuItem(
                    value: 'support_task',
                    child: Text('客服任務 support_task'),
                  ),
                ],
                onChanged: _sending
                    ? null
                    : (v) {
                        if (v == null) {
                          return;
                        }
                        setState(() => _type = v);
                      },
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: '標題',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: _required,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: '內容',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                minLines: 3,
                maxLines: 6,
                validator: _required,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _deepLinkCtrl,
                decoration: const InputDecoration(
                  labelText: 'deepLink（可空，例如 /activity_detail）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _routeCtrl,
                decoration: const InputDecoration(
                  labelText: 'route（可空，例如 /shop）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),

              const Divider(height: 24),
              _sectionTitle('預覽'),
              _previewCard(),

              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_sending ? '送出中…' : '送出通知'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );

    if (!widget.standalone) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('推播中心'),
        actions: [
          IconButton(
            tooltip: '送出',
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      body: content,
    );
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

  Widget _targetSelector() {
    return SegmentedButton<_TargetMode>(
      segments: const [
        ButtonSegment<_TargetMode>(
          value: _TargetMode.allUsers,
          label: Text('全部會員'),
          icon: Icon(Icons.group),
        ),
        ButtonSegment<_TargetMode>(
          value: _TargetMode.byRole,
          label: Text('依角色'),
          icon: Icon(Icons.manage_accounts),
        ),
        ButtonSegment<_TargetMode>(
          value: _TargetMode.singleUid,
          label: Text('指定 UID'),
          icon: Icon(Icons.person_search),
        ),
      ],
      selected: <_TargetMode>{_targetMode},
      onSelectionChanged: _sending
          ? null
          : (selection) {
              final v = selection.first;
              setState(() => _targetMode = v);
            },
    );
  }

  Widget _previewCard() {
    final cs = Theme.of(context).colorScheme;
    final title = _titleCtrl.text.trim().isEmpty
        ? '(標題)'
        : _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim().isEmpty ? '(內容)' : _bodyCtrl.text.trim();

    return Card(
      elevation: 1,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: cs.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              child: Icon(_iconForType(_type), color: cs.onSurface),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chipPill(cs, _typeLabel(_type)),
                if (_deepLinkCtrl.text.trim().isNotEmpty)
                  _chipPill(cs, 'deepLink'),
                if (_routeCtrl.text.trim().isNotEmpty) _chipPill(cs, 'route'),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _chipPill(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
