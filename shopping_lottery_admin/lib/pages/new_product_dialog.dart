// lib/pages/new_product_dialog.dart
//
// ✅ NewProductDialog（最終完整版｜可編譯｜Web拖放 onDropFile｜移除 finally return｜withValues 取代 withOpacity）
// ------------------------------------------------------------
// 功能：
// - 新增/編輯商品（id/title/price/isActive）
// - 選取多張圖片（file_selector）
// - Web 支援拖放上傳（flutter_dropzone: onDropFile）
// - 已上傳圖片可設主圖 / 刪除
// - 圖片可拖曳排序（reorderables: ReorderableWrap）
// - 上傳進度顯示（單檔 + 平均）
// - 儲存後寫入 Firestore（透過 ProductService）
//
// 依賴：
// - file_selector
// - flutter_dropzone
// - reorderables
// - provider
// - services/product_service.dart
// ------------------------------------------------------------

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'; // ✅ includes Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:provider/provider.dart';
import 'package:reorderables/reorderables.dart';

import '../services/product_service.dart';

class NewProductDialog extends StatefulWidget {
  final String? initialProductId;
  final Map<String, dynamic>? initialData;

  const NewProductDialog({super.key, this.initialProductId, this.initialData});

  @override
  State<NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<NewProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool _isActive = true;

  final List<XFile> _pickedFiles = [];
  final List<Map<String, String?>> _uploadedImages = []; // {url, path}
  final Map<String, double> _fileProgress = {};
  bool _uploading = false;
  String? _error;

  // dropzone controller for web drag-drop
  DropzoneViewController? _dropCtrl;
  bool _isDropHover = false;

  String get _productId => _idCtrl.text.trim();

  @override
  void initState() {
    super.initState();

    if (widget.initialProductId != null) {
      _idCtrl.text = widget.initialProductId!;
    }

    final data = widget.initialData;
    if (data != null) {
      _titleCtrl.text = (data['title'] ?? '').toString();
      _priceCtrl.text = (data['price'] ?? '').toString();
      _isActive = (data['isActive'] ?? true) == true;

      final imgs = data['images'];
      if (imgs is List) {
        for (final i in imgs) {
          if (i is String && i.trim().isNotEmpty) {
            _uploadedImages.add({'url': i, 'path': null});
          } else if (i is Map) {
            final url = (i['url'] ?? '').toString();
            final path = (i['path'] ?? '').toString();
            if (url.trim().isNotEmpty) {
              _uploadedImages.add({
                'url': url,
                'path': path.isEmpty ? null : path,
              });
            }
          }
        }
      }

      final primary = data['primaryImage'];
      if (primary is Map) {
        final pu = (primary['url'] ?? '').toString().trim();
        final pp = (primary['path'] ?? '').toString().trim();
        if (pu.isNotEmpty) {
          final found = _uploadedImages.any((e) => (e['url'] ?? '') == pu);
          if (!found) {
            _uploadedImages.insert(0, {
              'url': pu,
              'path': pp.isEmpty ? null : pp,
            });
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      );
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isEmpty) return;

      if (!mounted) return;
      setState(() => _pickedFiles.addAll(files));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '選取檔案失敗：$e');
    }
  }

  Widget _buildDropZone() {
    if (!kIsWeb) return const SizedBox.shrink();

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _isDropHover
            ? Colors.blue.withValues(alpha: 15) // ✅ replaces withOpacity(0.06)
            : Colors.grey.shade50,
        border: Border.all(color: _isDropHover ? Colors.blue : Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          DropzoneView(
            onCreated: (c) => _dropCtrl = c,
            onHover: () {
              if (!mounted) return;
              setState(() => _isDropHover = true);
            },
            onLeave: () {
              if (!mounted) return;
              setState(() => _isDropHover = false);
            },

            // ✅ FIX: onDrop deprecated -> use onDropFile
            // ✅ FIX: 避免 finally 裡 return（control_flow_in_finally）
            onDropFile: (file) async {
              try {
                final ctrl = _dropCtrl;
                if (ctrl == null) return;

                final name = await ctrl.getFilename(file);
                final mime = await ctrl.getFileMIME(file);
                final bytes = await ctrl.getFileData(file);

                final xfile = XFile.fromData(bytes, name: name, mimeType: mime);

                if (!mounted) return;
                setState(() {
                  _pickedFiles.add(xfile);
                  _isDropHover = false;
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _error = 'Drop 失敗：$e';
                  _isDropHover = false;
                });
              }
            },

            operation: DragOperation.copy,
          ),
          Center(child: Text(_isDropHover ? '放開以上傳' : '將圖片拖放到此處，或點選下方按鈕挑選')),
        ],
      ),
    );
  }

  Widget _buildPreviewGrid() {
    final tiles = <Widget>[];

    // 1) already uploaded
    for (final m in _uploadedImages) {
      final url = (m['url'] ?? '').trim();
      final path = m['path'];
      if (url.isNotEmpty) {
        tiles.add(_buildUploadedTile(url: url, path: path));
      }
    }

    // 2) picked
    for (final f in _pickedFiles) {
      tiles.add(_buildPickedTile(f));
    }

    // 3) add tile (固定最後，不讓 reorder）
    final addTileIndex = tiles.length;
    tiles.add(_buildAddTile());

    return ReorderableWrap(
      spacing: 8,
      runSpacing: 8,
      needsLongPressDraggable: true,
      onReorder: (oldIndex, newIndex) {
        // ✅ 不允許拖動「新增」格子
        if (oldIndex == addTileIndex || newIndex == addTileIndex) return;

        setState(() {
          final uploadedLen = _uploadedImages.length;
          final totalLen = uploadedLen + _pickedFiles.length; // 不含 addTile

          if (oldIndex < 0 || oldIndex >= totalLen) return;
          if (newIndex < 0) newIndex = 0;
          if (newIndex >= totalLen) newIndex = totalLen - 1;

          // uploaded 區
          if (oldIndex < uploadedLen && newIndex < uploadedLen) {
            final item = _uploadedImages.removeAt(oldIndex);
            _uploadedImages.insert(newIndex, item);
            return;
          }

          // picked 區
          if (oldIndex >= uploadedLen && newIndex >= uploadedLen) {
            final pOld = oldIndex - uploadedLen;
            final pNew = newIndex - uploadedLen;
            if (pOld < 0 || pOld >= _pickedFiles.length) return;
            final item = _pickedFiles.removeAt(pOld);
            _pickedFiles.insert(pNew.clamp(0, _pickedFiles.length), item);
            return;
          }

          // 跨區移動（目前不做）
        });
      },
      children: tiles,
    );
  }

  Widget _buildUploadedTile({required String url, String? path}) {
    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[100],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: PopupMenuButton<String>(
            onSelected: (v) async {
              final svc = context.read<ProductService>();
              final pid = _productId;

              if (pid.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請先輸入商品 ID 再操作圖片')),
                );
                return;
              }

              if (v == 'remove') {
                await svc.removeProductImage(
                  productId: pid,
                  imageUrl: url,
                  storagePath: path,
                );
                if (!mounted) return;
                setState(
                  () => _uploadedImages.removeWhere((e) => e['url'] == url),
                );
              } else if (v == 'primary') {
                await svc.setPrimaryImage(pid, url: url, path: path);
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已設定為主圖')));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'primary', child: Text('設為主圖')),
              PopupMenuItem(value: 'remove', child: Text('刪除')),
            ],
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black45,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickedTile(XFile f) {
    final p = (_fileProgress[f.name] ?? 0.0).clamp(0.0, 1.0);

    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[100],
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<Uint8List>(
            future: f.readAsBytes(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (!snap.hasData) return const Icon(Icons.image);
              return Image.memory(snap.data!, fit: BoxFit.cover);
            },
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: () => setState(() => _pickedFiles.remove(f)),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${(p * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: _uploading ? null : _pickFiles,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: const Center(
          child: Icon(Icons.add_a_photo_outlined, color: Colors.black38),
        ),
      ),
    );
  }

  double _avgProgress() {
    if (_fileProgress.isEmpty) return 0.0;
    final sum = _fileProgress.values.fold<double>(0.0, (a, b) => a + b);
    return (sum / _fileProgress.length).clamp(0.0, 1.0);
  }

  Future<void> _uploadAndSave() async {
    final svc = context.read<ProductService>();
    final productId = _productId;

    if (productId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入商品 ID')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _uploading = true;
      _error = null;
      _fileProgress.clear();
    });

    try {
      final List<Map<String, String>> uploadedNew = [];

      for (final f in _pickedFiles) {
        if (!kIsWeb) {
          final res = await svc.uploadProductStream(
            productId: productId,
            openStream: () => f.openRead().map<List<int>>((b) => b),
            filename: f.name,
            onProgress: (p) => setState(() => _fileProgress[f.name] = p),
          );
          uploadedNew.add({'url': res['url']!, 'path': res['path']!});
        } else {
          final bytes = await f.readAsBytes();
          final res = await svc.uploadProductBytes(
            productId: productId,
            bytes: bytes,
            filename: f.name,
            onProgress: (p) => setState(() => _fileProgress[f.name] = p),
          );
          uploadedNew.add({'url': res['url']!, 'path': res['path']!});
        }
      }

      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;

      final productData = <String, dynamic>{
        'id': productId,
        'title': _titleCtrl.text.trim(),
        'price': price,
        'isActive': _isActive,
      };
      await svc.upsert(id: productId, data: productData);

      if (uploadedNew.isNotEmpty) {
        await svc.appendProductImages(productId, uploadedNew);
        if (!mounted) return;
        setState(() {
          for (final u in uploadedNew) {
            _uploadedImages.add({'url': u['url']!, 'path': u['path']!});
          }
          _pickedFiles.clear();
          _fileProgress.clear();
        });
      }

      // Persist image order
      if (_uploadedImages.isNotEmpty) {
        final urlsOrder = _uploadedImages
            .map((m) => (m['url'] ?? '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
        await svc.updateImageOrder(productId, urlsOrder);
      }

      if (!mounted) return;
      setState(() => _uploading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商品儲存完成')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = '儲存失敗：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avgProgress();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.initialProductId == null
                            ? '新增商品 (Admin)'
                            : '編輯商品 (Admin)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _idCtrl,
                        decoration: const InputDecoration(
                          labelText: '商品 ID (例如 p_s5)',
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? '請填寫商品 ID' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(labelText: '商品標題'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? '請填寫標題' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '價格 (數字)'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('上架 (isActive)'),
                          const Spacer(),
                          Switch(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (kIsWeb) _buildDropZone(),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '圖片 (可多張，拖曳可排序)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPreviewGrid(),
                      const SizedBox(height: 12),
                      if (_uploading)
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: _fileProgress.isEmpty ? null : avg,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _fileProgress.isEmpty
                                  ? '上傳中...'
                                  : '${(avg * 100).toStringAsFixed(0)}%',
                            ),
                          ],
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _uploading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _uploading ? null : _uploadAndSave,
                      child: const Text('儲存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
