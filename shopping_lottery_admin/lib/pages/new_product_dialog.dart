// lib/pages/new_product_dialog.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:provider/provider.dart';
import 'package:reorderables/reorderables.dart';

import '../services/product_service.dart';

class NewProductDialog extends StatefulWidget {
  final String? initialProductId;
  final Map<String, dynamic>? initialData;
  const NewProductDialog({Key? key, this.initialProductId, this.initialData}) : super(key: key);

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
  final List<Map<String, String?>> _uploadedImages = [];
  final Map<String, double> _fileProgress = {};
  bool _uploading = false;
  String? _error;

  // dropzone controller for web drag-drop
  DropzoneViewController? _dropCtrl;
  bool _isDropHover = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProductId != null) _idCtrl.text = widget.initialProductId!;
    if (widget.initialData != null) {
      _titleCtrl.text = (widget.initialData!['title'] ?? '').toString();
      _priceCtrl.text = (widget.initialData!['price'] ?? '').toString();
      _isActive = widget.initialData!['isActive'] ?? true;
      final imgs = widget.initialData!['images'];
      if (imgs is List) {
        for (final i in imgs) {
          if (i is String) _uploadedImages.add({'url': i, 'path': null});
          if (i is Map) _uploadedImages.add({'url': (i['url'] ?? '').toString(), 'path': (i['path'] ?? '').toString()});
        }
      }
      final primary = widget.initialData!['primaryImage'];
      if (primary is Map && (primary['url'] ?? '').toString().isNotEmpty) {
        final pu = (primary['url'] ?? '').toString();
        final found = _uploadedImages.any((e) => e['url'] == pu);
        if (!found) _uploadedImages.insert(0, {'url': pu, 'path': (primary['path'] ?? '').toString()});
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
      final typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif']);
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      if (files.isEmpty) return;
      setState(() => _pickedFiles.addAll(files));
    } catch (e) {
      setState(() => _error = '選取檔案失敗：$e');
    }
  }

  // web drag handler: convert drop to XFile-like bytes
  Future<void> _onDrop(dynamic event) async {
    if (_dropCtrl == null) return;
    try {
      final name = await _dropCtrl!.getFilename(event);
      final mime = await _dropCtrl!.getFileMIME(event);
      final size = await _dropCtrl!.getFileSize(event);
      final bytes = await _dropCtrl!.getFileData(event);
      // Create an in-memory XFile via XFile.fromData (file_selector XFile has constructor)
      final xfile = XFile.fromData(bytes, name: name, mimeType: mime);
      setState(() => _pickedFiles.add(xfile));
    } catch (e) {
      setState(() => _error = 'Drop 失敗：$e');
    }
  }

  Widget _buildDropZone() {
    if (!kIsWeb) return const SizedBox.shrink();
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _isDropHover ? Colors.blue.withOpacity(0.06) : Colors.grey.shade50,
        border: Border.all(color: _isDropHover ? Colors.blue : Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          DropzoneView(
            onCreated: (c) => _dropCtrl = c,
            onHover: () => setState(() => _isDropHover = true),
            onLeave: () => setState(() => _isDropHover = false),
            onDrop: (ev) async {
              await _onDrop(ev);
              setState(() => _isDropHover = false);
            },
            operation: DragOperation.copy,
          ),
          Center(child: Text(_isDropHover ? '放開以上傳' : '將圖片拖放到此處，或點選下方按鈕挑選')),
        ],
      ),
    );
  }

  Widget _buildPreviewGrid() {
    // build widgets for uploaded and picked files
    final tiles = <Widget>[];
    for (final m in _uploadedImages) {
      final url = m['url'] ?? '';
      final path = m['path'];
      tiles.add(_buildUploadedTile(url: url, path: path));
    }
    for (final f in _pickedFiles) {
      tiles.add(_buildPickedTile(f));
    }
    tiles.add(_buildAddTile());
    // Use ReorderableWrap for drag reorder
    return ReorderableWrap(
      spacing: 8,
      runSpacing: 8,
      needsLongPressDraggable: true,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < _uploadedImages.length) {
            // reorder uploaded images
            final item = _uploadedImages.removeAt(oldIndex);
            _uploadedImages.insert(newIndex.clamp(0, _uploadedImages.length), item);
          } else {
            // move in picked files (less common)
            final pIndex = oldIndex - _uploadedImages.length;
            final npIndex = newIndex - _uploadedImages.length;
            final item = _pickedFiles.removeAt(pIndex);
            _pickedFiles.insert(npIndex.clamp(0, _pickedFiles.length), item);
          }
        });
      },
      children: tiles,
    );
  }

  Widget _buildUploadedTile({required String url, String? path}) {
    return Stack(children: [
      Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[100]),
        child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
      ),
      Positioned(
        right: 2,
        top: 2,
        child: PopupMenuButton<String>(
          onSelected: (v) async {
            final svc = context.read<ProductService>();
            if (v == 'remove') {
              await svc.removeProductImage(productId: _idCtrl.text.trim(), imageUrl: url, storagePath: path);
              setState(() => _uploadedImages.removeWhere((e) => e['url'] == url));
            } else if (v == 'primary') {
              await svc.setPrimaryImage(_idCtrl.text.trim(), url: url, path: path);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已設定為主圖')));
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'primary', child: Text('設為主圖')),
            const PopupMenuItem(value: 'remove', child: Text('刪除')),
          ],
          child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45), child: const Icon(Icons.more_vert, color: Colors.white, size: 18)),
        ),
      ),
    ]);
  }

  Widget _buildPickedTile(XFile f) {
    return Stack(children: [
      Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[100]),
        child: FutureBuilder<Uint8List?>(
          future: f.readAsBytes(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final bytes = snap.data;
            if (bytes == null) return const Icon(Icons.image);
            return Image.memory(bytes, fit: BoxFit.cover);
          },
        ),
      ),
      Positioned(
        right: 2,
        top: 2,
        child: InkWell(
          onTap: () => setState(() => _pickedFiles.remove(f)),
          child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54), child: const Icon(Icons.close, color: Colors.white, size: 18)),
        ),
      ),
      Positioned(
        left: 4,
        bottom: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
          child: Text('${((_fileProgress[f.name] ?? 0.0) * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
      ),
    ]);
  }

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: _pickFiles,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
        child: const Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.black38)),
      ),
    );
  }

  Future<void> _uploadAndSave() async {
    final svc = context.read<ProductService>();
    final productId = _idCtrl.text.trim();
    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入商品 ID')));
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
      final total = _pickedFiles.length;
      for (var i = 0; i < total; i++) {
        final f = _pickedFiles[i];
        // non-web: use stream to avoid large memory
        if (!kIsWeb) {
          final res = await svc.uploadProductStream(
            productId: productId,
            openStream: () => f.openRead().map((b) => b is List<int> ? b : List<int>.from(b)),
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
      final productData = {
        'id': productId,
        'title': _titleCtrl.text.trim(),
        'price': price,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await svc.upsert(id: productId, data: productData);

      if (uploadedNew.isNotEmpty) {
        await svc.appendProductImages(productId, uploadedNew);
        setState(() {
          for (final u in uploadedNew) _uploadedImages.add({'url': u['url']!, 'path': u['path']!});
          _pickedFiles.clear();
          _fileProgress.clear();
        });
      }

      // Persist image order to Firestore when user reordered
      if (_uploadedImages.isNotEmpty) {
        final urlsOrder = _uploadedImages.map((m) => m['url']!).toList();
        await svc.updateImageOrder(productId, urlsOrder);
      }

      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('商品儲存完成')));
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = '儲存失敗：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(widget.initialProductId == null ? '新增商品 (Admin)' : '編輯商品 (Admin)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close))
            ]),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(children: [
                TextFormField(controller: _idCtrl, decoration: const InputDecoration(labelText: '商品 ID (例如 p_s5)'), validator: (v) => (v ?? '').trim().isEmpty ? '請填寫商品 ID' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '商品標題'), validator: (v) => (v ?? '').trim().isEmpty ? '請填寫標題' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '價格 (數字)')),
                const SizedBox(height: 12),
                Row(children: [const Text('上架 (isActive)'), const Spacer(), Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v))]),
                const SizedBox(height: 12),
                if (kIsWeb) _buildDropZone(),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: const Text('圖片 (可多張，拖曳可排序)', style: TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(height: 8),
                _buildPreviewGrid(),
                const SizedBox(height: 12),
                if (_uploading) Column(children: [LinearProgressIndicator(value: _fileProgress.isEmpty ? null : _fileProgress.values.fold(0.0, (a, b) => a + b) / (_fileProgress.length == 0 ? 1 : _fileProgress.length)), const SizedBox(height: 8), Text('${(_fileProgress.values.fold(0.0, (a, b) => a + b) / (_fileProgress.length == 0 ? 1 : _fileProgress.length) * 100).toStringAsFixed(0)}%')]),
                if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Colors.red))],
              ]),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _uploading ? null : _uploadAndSave, child: const Text('儲存')),
            ])
          ]),
        ),
      ),
    );
  }
}
