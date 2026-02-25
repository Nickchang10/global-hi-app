import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/product_service.dart';
import '../services/category_service.dart';

class ProductDialog extends StatefulWidget {
  /// initial != null 代表「編輯」
  final Map<String, dynamic>? initial;

  const ProductDialog({super.key, this.initial});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();

  // fields
  late final String _id;
  late final bool _isEdit;

  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late final VoidCallback _imageUrlListener;

  String _categoryId = '__none__';
  bool _isActive = true;

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _isEdit = init != null;

    // id：編輯用既有 id；新增用自動生成
    _id = _isEdit
        ? _s(init!['id'])
        : FirebaseFirestore.instance.collection('products').doc().id;

    // preload values
    if (init != null) {
      _titleCtrl.text = _s(init['title']);
      _priceCtrl.text = _numText(init['price']);
      _vendorCtrl.text = _s(init['vendorId']);
      _imageUrlCtrl.text = _s(init['imageUrl']);
      _descCtrl.text = _s(init['description']);
      _categoryId = _s(init['categoryId']).isEmpty
          ? '__none__'
          : _s(init['categoryId']);
      _isActive = (init['isActive'] ?? true) == true;
    } else {
      _vendorCtrl.text = 'osmile';
      _isActive = true;
      _categoryId = '__none__';
    }

    // 讓圖片 URL 改動時能即時刷新預覽
    _imageUrlListener = () {
      if (!mounted) {
        return;
      }
      setState(() {});
    };
    _imageUrlCtrl.addListener(_imageUrlListener);
  }

  @override
  void dispose() {
    _imageUrlCtrl.removeListener(_imageUrlListener);
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _vendorCtrl.dispose();
    _imageUrlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _numText(dynamic v) {
    if (v == null) {
      return '';
    }
    if (v is num) {
      return v.toString();
    }
    final n = num.tryParse(v.toString());
    return n == null ? '' : n.toString();
  }

  num _parsePrice(String s) => num.tryParse(s.trim()) ?? 0;

  void _snack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  List<Map<String, dynamic>> _dedupById(List<Map<String, dynamic>> raw) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final m in raw) {
      final id = _s(m['id']);
      if (id.isEmpty) {
        continue;
      }
      if (seen.add(id)) {
        out.add(m);
      }
    }
    return out;
  }

  Future<void> _save() async {
    setState(() {
      _err = null;
    });

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final prodSvc = context.read<ProductService>();

      final title = _titleCtrl.text.trim();
      final vendorId = _vendorCtrl.text.trim().isEmpty
          ? 'osmile'
          : _vendorCtrl.text.trim();
      final price = _parsePrice(_priceCtrl.text);
      final imageUrl = _imageUrlCtrl.text.trim();
      final desc = _descCtrl.text.trim();

      final data = <String, dynamic>{
        'title': title,
        'vendorId': vendorId,
        'price': price,
        'isActive': _isActive,
        'description': desc,
        'categoryId': _categoryId == '__none__' ? '' : _categoryId,
      };

      // 圖片：極簡只用 URL（不做上傳）
      // 但仍寫入兼容欄位，讓你首頁/列表縮圖穩定顯示
      if (imageUrl.isNotEmpty) {
        data['imageUrl'] = imageUrl;
        data['primaryImage'] = {'url': imageUrl, 'path': null};
        data['images'] = [
          {'url': imageUrl, 'path': null},
        ];
        data['imagesUrls'] = [imageUrl];
      } else {
        // 若清空圖片，則一起清掉兼容欄位（避免顯示舊圖）
        data['imageUrl'] = '';
        data['primaryImage'] = null;
        data['images'] = [];
        data['imagesUrls'] = [];
      }

      await prodSvc.upsert(id: _id, data: data);

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
      _snack(_isEdit ? '已更新商品' : '已新增商品');
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final catSvc = context.read<CategoryService>();

    return AlertDialog(
      title: Text(_isEdit ? '編輯商品' : '新增商品'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顯示 ID（只讀）
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ID：$_id',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '商品標題',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '請輸入商品標題';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '價格（數字）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) {
                      return '請輸入價格';
                    }
                    final n = num.tryParse(s);
                    if (n == null) {
                      return '價格格式不正確';
                    }
                    if (n < 0) {
                      return '價格不可小於 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // 分類：可選（沒有就保持空字串）
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: catSvc.streamCategories(),
                  builder: (context, snap) {
                    final raw = snap.data ?? [];
                    final cats = _dedupById(raw);

                    // 若目前 _categoryId 不存在，退回 __none__
                    final ids = <String>{
                      '__none__',
                      ...cats.map((e) => _s(e['id'])),
                    };
                    final safeValue = ids.contains(_categoryId)
                        ? _categoryId
                        : '__none__';

                    if (safeValue != _categoryId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _categoryId = safeValue;
                        });
                      });
                    }

                    return DropdownButtonFormField<String>(
                      // ✅ 修正：避免 "$safeValue_" 被解析成 safeValue_ 變數
                      key: ValueKey(
                        'product_dialog_category_${_id}_${safeValue}_len${cats.length}',
                      ),
                      initialValue: safeValue, // ✅ 取代已 deprecated 的 value:
                      decoration: const InputDecoration(
                        labelText: '分類（可不選）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '__none__',
                          child: Text('不指定'),
                        ),
                        ...cats.map((c) {
                          final id = _s(c['id']);
                          final name = _s(c['name']).isEmpty
                              ? id
                              : _s(c['name']);
                          final active = (c['isActive'] ?? true) == true;
                          return DropdownMenuItem(
                            value: id,
                            child: Text(active ? name : '$name（停用）'),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _categoryId = v ?? '__none__';
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),

                // 供應商：極簡保留一個欄位（預設 osmile）
                TextFormField(
                  controller: _vendorCtrl,
                  decoration: const InputDecoration(
                    labelText: '廠商ID（預設 osmile）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _imageUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: '圖片網址（可不填）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                // 小預覽：如果有 URL 就顯示縮圖
                if (_imageUrlCtrl.text.trim().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _imageUrlCtrl.text.trim(),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: cs.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '簡短描述（可不填）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('上架'),
                  value: _isActive,
                  onChanged: (v) {
                    setState(() {
                      _isActive = v;
                    });
                  },
                ),

                if (_err != null) ...[
                  const SizedBox(height: 8),
                  Text(_err!, style: TextStyle(color: cs.error, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('儲存'),
        ),
      ],
    );
  }
}
