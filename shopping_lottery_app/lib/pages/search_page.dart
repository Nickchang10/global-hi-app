// lib/pages/search_page.dart
//
// ✅ SearchPage（最終完整版｜可直接使用｜已修正 lint）
// - ✅ 修正：curly_braces_in_flow_control_structures（所有 if 皆使用 {}）
// - ✅ 修正：prefer_const_constructors（能 const 的 widget 全部 const 化）
// - 功能：搜尋輸入、熱門關鍵字、搜尋歷史、結果列表（示範）
// - 可自行替換 _mockSearch() 改接 Firestore / API
//
// 無額外套件依賴（只用 Flutter SDK）

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  static const routeName = '/search';

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  final _rand = Random();
  Timer? _debounce;

  bool _loading = false;
  String _q = '';

  final List<String> _hotKeywords = const <String>[
    'ED1000',
    '折扣碼',
    '健康手錶',
    '抽獎活動',
    '點數商城',
    '睡眠',
    '心率',
    '保固',
  ];

  final List<String> _history = <String>[];

  List<_SearchItem> _results = const <_SearchItem>[];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onQueryChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onQueryChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final v = _ctrl.text.trim();
    if (v == _q) {
      return;
    }
    setState(() => _q = v);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) {
        return;
      }
      await _doSearch(_q, addToHistory: false);
    });
  }

  Future<void> _doSearch(String keyword, {required bool addToHistory}) async {
    final q = keyword.trim();

    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _results = const <_SearchItem>[];
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final items = await _mockSearch(q);
      if (!mounted) {
        return;
      }

      setState(() {
        _results = items;
        _loading = false;
      });

      if (addToHistory) {
        _addHistory(q);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('搜尋失敗：$e')));
    }
  }

  Future<List<_SearchItem>> _mockSearch(String q) async {
    await Future.delayed(const Duration(milliseconds: 220));

    final pool = <_SearchItem>[
      const _SearchItem(
        title: 'ED1000 智慧手錶',
        subtitle: '熱銷商品｜健康追蹤與 SOS 守護',
        type: 'product',
      ),
      const _SearchItem(
        title: '點數商城',
        subtitle: '用點數兌換好禮｜折價券、周邊',
        type: 'feature',
      ),
      const _SearchItem(
        title: '抽獎活動｜本週大獎',
        subtitle: '完成任務拿票券，立即抽好禮',
        type: 'lottery',
      ),
      const _SearchItem(
        title: '訂單查詢',
        subtitle: '查看訂單狀態、物流、付款資訊',
        type: 'orders',
      ),
      const _SearchItem(
        title: '客服中心',
        subtitle: '常見問題/聯絡方式/工單',
        type: 'support',
      ),
      const _SearchItem(title: '健康中心', subtitle: '步數、睡眠、心率趨勢', type: 'health'),
      const _SearchItem(title: '優惠券', subtitle: '我的折扣碼/可用優惠券', type: 'coupons'),
    ];

    final s = q.toLowerCase();
    final matched = pool.where((e) {
      return e.title.toLowerCase().contains(s) ||
          e.subtitle.toLowerCase().contains(s) ||
          e.type.toLowerCase().contains(s);
    }).toList();

    if (matched.isEmpty) {
      final n = 2 + _rand.nextInt(4);
      return List.generate(n, (i) {
        return _SearchItem(
          title: '搜尋結果：$q（示範）#${i + 1}',
          subtitle: '這是示範資料，請改接你的資料來源',
          type: 'demo',
        );
      });
    }

    return matched;
  }

  void _addHistory(String q) {
    if (q.trim().isEmpty) {
      return;
    }
    setState(() {
      _history.remove(q);
      _history.insert(0, q);
      if (_history.length > 12) {
        _history.removeLast();
      }
    });
  }

  void _tapHot(String kw) {
    _ctrl.text = kw;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
    _doSearch(kw, addToHistory: true);
  }

  void _tapHistory(String kw) {
    _ctrl.text = kw;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
    _doSearch(kw, addToHistory: true);
  }

  void _clearInput() {
    setState(() {
      _ctrl.clear();
      _q = '';
      _results = const <_SearchItem>[];
      _loading = false;
    });
    _focus.requestFocus();
  }

  void _clearHistory() {
    setState(() => _history.clear());
  }

  void _openResult(_SearchItem item) {
    final route = switch (item.type) {
      'product' => '/products',
      'lottery' => '/lottery',
      'health' => '/health',
      'support' => '/help_center',
      'orders' => '/orders',
      'coupons' => '/coupons',
      _ => null,
    };

    if (route == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('示範：點到「${item.title}」')));
      return;
    }

    try {
      Navigator.of(context).pushNamed(route);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法前往：$route（請確認 main.dart 已註冊路由）')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜尋'),
        actions: [
          if (_q.isNotEmpty)
            IconButton(
              tooltip: '清除',
              onPressed: _clearInput,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _searchBar(cs),
          const SizedBox(height: 12),
          if (_q.isEmpty) ...[
            const _SectionTitle('熱門關鍵字'),
            const SizedBox(height: 8),
            _hotChips(),
            const SizedBox(height: 14),
            const _SectionTitle('搜尋紀錄'),
            const SizedBox(height: 8),
            _historyBox(),
          ] else ...[
            const _SectionTitle('搜尋結果'),
            const SizedBox(height: 8),
            _resultBox(),
          ],
        ],
      ),
    );
  }

  Widget _searchBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: '輸入關鍵字（商品/功能/活動）',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (v) {
                final q = v.trim();
                if (q.isEmpty) {
                  return;
                }
                _doSearch(q, addToHistory: true);
              },
            ),
          ),
          if (_q.isNotEmpty)
            IconButton(
              tooltip: '清除',
              onPressed: _clearInput,
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _hotChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _hotKeywords.map((kw) {
        return ActionChip(label: Text(kw), onPressed: () => _tapHot(kw));
      }).toList(),
    );
  }

  Widget _historyBox() {
    if (_history.isEmpty) {
      return const _EmptyBox('尚無搜尋紀錄');
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '最近搜尋',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(onPressed: _clearHistory, child: const Text('清除')),
              ],
            ),
            const Divider(height: 1),
            ..._history.map((kw) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history),
                title: Text(kw),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _tapHistory(kw),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _resultBox() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (_results.isEmpty) {
      return const _EmptyBox('沒有找到結果（示範）');
    }

    return Card(
      elevation: 0,
      child: Column(
        children: [
          for (int i = 0; i < _results.length; i++) ...[
            ListTile(
              leading: _typeIcon(_results[i].type),
              title: Text(
                _results[i].title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(_results[i].subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openResult(_results[i]),
            ),
            if (i != _results.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _typeIcon(String type) {
    final icon = switch (type) {
      'product' => Icons.storefront_outlined,
      'lottery' => Icons.casino_outlined,
      'health' => Icons.favorite_outline,
      'support' => Icons.support_agent,
      'orders' => Icons.receipt_long,
      'coupons' => Icons.confirmation_number_outlined,
      _ => Icons.search,
    };
    return CircleAvatar(
      backgroundColor: Colors.grey.withValues(alpha: 0.12),
      child: Icon(icon, color: Colors.black87),
    );
  }
}

class _SearchItem {
  final String title;
  final String subtitle;
  final String type;

  const _SearchItem({
    required this.title,
    required this.subtitle,
    required this.type,
  });
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
