import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// AdminLanguagePage（正式版｜完整版｜可直接編譯）
///
/// Firestore 建議儲存位置：
///   site_contents/app_settings
///     - defaultLocale: String (e.g. "zh_TW")
///     - supportedLocales: List<Map>
///         [{ code: "zh_TW", name: "繁體中文", enabled: true, sort: 0 }, ...]
///     - updatedAt: Timestamp
///     - createdAt: Timestamp
class AdminLanguagePage extends StatefulWidget {
  const AdminLanguagePage({super.key});

  @override
  State<AdminLanguagePage> createState() => _AdminLanguagePageState();
}

class _AdminLanguagePageState extends State<AdminLanguagePage> {
  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance
      .collection('site_contents')
      .doc('app_settings');

  bool _busy = false;

  Future<void> _save({
    required String defaultLocale,
    required List<Map<String, dynamic>> supported,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (mounted) setState(() => _busy = true);
    try {
      await _ref.set({
        'defaultLocale': defaultLocale,
        'supportedLocales': supported,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已儲存語言設定')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_LocaleItem?> _openAddDialog() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final res = await showDialog<_LocaleItem>(
      context: context,
      builder: (dialogCtx) {
        final dialogMessenger = ScaffoldMessenger.of(dialogCtx);

        return AlertDialog(
          title: const Text('新增語言'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: '語言代碼（例如 zh_TW / en / ja）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '顯示名稱（例如 繁體中文 / English）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '建議格式：語言 en、繁中 zh_TW、簡中 zh_CN',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final code = codeCtrl.text.trim();
                final name = nameCtrl.text.trim();

                if (!_isValidLocaleCode(code)) {
                  dialogMessenger.showSnackBar(
                    const SnackBar(content: Text('語言代碼格式不正確（例如 zh_TW / en）')),
                  );
                  return;
                }
                if (name.isEmpty) {
                  dialogMessenger.showSnackBar(
                    const SnackBar(content: Text('顯示名稱不可為空')),
                  );
                  return;
                }

                Navigator.of(dialogCtx).pop(
                  _LocaleItem(code: code, name: name, enabled: true, sort: 0),
                );
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );

    codeCtrl.dispose();
    nameCtrl.dispose();
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('語言管理')),
            body: Center(
              child: Text(
                '讀取失敗：${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('語言管理')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() ?? <String, dynamic>{};
        final defaultLocale = (data['defaultLocale'] ?? 'zh_TW')
            .toString()
            .trim();

        final raw = (data['supportedLocales'] as List?) ?? const [];
        final items = raw
            .whereType<Map>()
            .map((m) => _LocaleItem.fromMap(m.cast<String, dynamic>()))
            .toList();

        if (items.isEmpty) {
          items.addAll([
            _LocaleItem(code: 'zh_TW', name: '繁體中文', enabled: true, sort: 0),
            _LocaleItem(code: 'en', name: 'English', enabled: true, sort: 10),
          ]);
        }

        items.sort((a, b) => a.sort.compareTo(b.sort));

        String currentDefault = defaultLocale;
        if (!items.any((e) => e.code == currentDefault)) {
          currentDefault = items.first.code;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('語言管理'),
            actions: [
              IconButton(
                tooltip: '新增語言',
                onPressed: _busy
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);

                        final added = await _openAddDialog();
                        if (added == null) return;

                        if (items.any((e) => e.code == added.code)) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('已存在語言代碼：${added.code}')),
                          );
                          return;
                        }

                        final nextSort = (items.isEmpty
                            ? 0
                            : items.last.sort + 10);
                        final newItems = [
                          ...items,
                          added.copyWith(sort: nextSort),
                        ];

                        await _save(
                          defaultLocale: currentDefault,
                          supported: _rebuildSort(
                            newItems,
                          ).map((e) => e.toMap()).toList(),
                        );
                      },
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0.7,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '預設語言',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        // ✅ FIX: value deprecated -> initialValue
                        initialValue: currentDefault,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: items
                            .where((e) => e.enabled)
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.code,
                                child: Text('${e.name} (${e.code})'),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) async {
                                final next = v ?? currentDefault;
                                await _save(
                                  defaultLocale: next,
                                  supported: _rebuildSort(
                                    items,
                                  ).map((e) => e.toMap()).toList(),
                                );
                              },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '只有「啟用」的語言才能設為預設語言',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '支援語言清單（可拖曳排序）',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0.6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  onReorder: _busy
                      ? (_, __) {}
                      : (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final list = [...items];
                          final moved = list.removeAt(oldIndex);
                          list.insert(newIndex, moved);

                          final normalized = _rebuildSort(list);
                          await _save(
                            defaultLocale: currentDefault,
                            supported: normalized
                                .map((e) => e.toMap())
                                .toList(),
                          );
                        },
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return ListTile(
                      key: ValueKey(it.code),
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(
                        it.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(it.code),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          Switch(
                            value: it.enabled,
                            onChanged: _busy
                                ? null
                                : (v) async {
                                    final list = items
                                        .map(
                                          (e) => e.code == it.code
                                              ? e.copyWith(enabled: v)
                                              : e,
                                        )
                                        .toList();

                                    String nextDefault = currentDefault;
                                    if (!list.any(
                                      (e) => e.code == nextDefault && e.enabled,
                                    )) {
                                      final firstEnabled = list.firstWhere(
                                        (e) => e.enabled,
                                        orElse: () =>
                                            list.first.copyWith(enabled: true),
                                      );
                                      nextDefault = firstEnabled.code;
                                    }

                                    await _save(
                                      defaultLocale: nextDefault,
                                      supported: _rebuildSort(
                                        list,
                                      ).map((e) => e.toMap()).toList(),
                                    );
                                  },
                          ),
                          IconButton(
                            tooltip: '刪除',
                            onPressed: _busy
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );

                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        title: const Text('刪除語言'),
                                        content: Text(
                                          '確定要刪除 ${it.name} (${it.code})？',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogCtx,
                                            ).pop(false),
                                            child: const Text('取消'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(
                                              dialogCtx,
                                            ).pop(true),
                                            child: const Text('刪除'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true) return;

                                    final list = items
                                        .where((e) => e.code != it.code)
                                        .toList();
                                    if (list.isEmpty) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('至少需要保留 1 個語言'),
                                        ),
                                      );
                                      return;
                                    }

                                    String nextDefault = currentDefault;
                                    if (!list.any(
                                      (e) => e.code == nextDefault,
                                    )) {
                                      nextDefault = list.first.code;
                                    }

                                    await _save(
                                      defaultLocale: nextDefault,
                                      supported: _rebuildSort(
                                        list,
                                      ).map((e) => e.toMap()).toList(),
                                    );
                                  },
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _LocaleItem {
  const _LocaleItem({
    required this.code,
    required this.name,
    required this.enabled,
    required this.sort,
  });

  final String code;
  final String name;
  final bool enabled;
  final int sort;

  _LocaleItem copyWith({String? code, String? name, bool? enabled, int? sort}) {
    return _LocaleItem(
      code: code ?? this.code,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'enabled': enabled,
    'sort': sort,
  };

  factory _LocaleItem.fromMap(Map<String, dynamic> m) {
    return _LocaleItem(
      code: (m['code'] ?? '').toString().trim(),
      name: (m['name'] ?? '').toString().trim(),
      enabled: m['enabled'] != false,
      sort: _toInt(m['sort'], fallback: 0),
    );
  }
}

List<_LocaleItem> _rebuildSort(List<_LocaleItem> list) {
  final out = <_LocaleItem>[];
  for (int i = 0; i < list.length; i++) {
    out.add(list[i].copyWith(sort: i * 10));
  }
  return out;
}

bool _isValidLocaleCode(String code) {
  if (code.isEmpty) return false;
  final r = RegExp(r'^[a-z]{2,3}([_-][A-Z]{2})?$');
  return r.hasMatch(code);
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}
