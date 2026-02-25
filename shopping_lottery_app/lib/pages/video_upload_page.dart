import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VideoUploadPage extends StatefulWidget {
  const VideoUploadPage({super.key});

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  File? _videoFile;
  final TextEditingController _descController = TextEditingController();
  Map<String, dynamic>? _selectedProduct;

  final List<Map<String, dynamic>> _sampleProducts = [
    {
      "name": "Osmile 智慧手錶 ED1000",
      "price": 3990,
      "image": "https://picsum.photos/200/200?random=11",
    },
    {
      "name": "兒童定位手錶 KX5",
      "price": 2590,
      "image": "https://picsum.photos/200/200?random=12",
    },
    {
      "name": "健康手環 FitGo Pro",
      "price": 1890,
      "image": "https://picsum.photos/200/200?random=13",
    },
  ];

  bool _uploading = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _videoFile = File(picked.path));
    }
  }

  void _selectProduct() {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => Container(
        height: 280,
        padding: const EdgeInsets.all(10),
        child: ListView.builder(
          itemCount: _sampleProducts.length,
          itemBuilder: (context, i) {
            final p = _sampleProducts[i];
            return Card(
              child: ListTile(
                leading: Image.network(p["image"], width: 60),
                title: Text(p["name"]),
                subtitle: Text("NT\$${p["price"]}"),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _selectedProduct = p);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _uploadVideo() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (_uploading) return;

    if (_videoFile == null || _descController.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text("請選擇影片並輸入描述")));
      return;
    }

    setState(() => _uploading = true);

    messenger.showSnackBar(const SnackBar(content: Text("上傳中... 🚀")));

    try {
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      messenger.showSnackBar(const SnackBar(content: Text("影片上傳成功 ✅")));

      nav.pop({
        // ✅ null-aware：這裡 _videoFile 保證非 null，但維持簡潔安全寫法
        "url": _videoFile?.path ?? "",
        "desc": _descController.text.trim(),
        "product": _selectedProduct,
        "likes": 0,
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text("上傳失敗：$e")));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ prefer_null_aware_operators：用 ?. 串接取值
    final pickedName = _videoFile?.path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: const Text("上傳短影片"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_videoFile == null)
              GestureDetector(
                onTap: _uploading ? null : _pickVideo,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Text(_uploading ? "上傳中…請稍候" : "📹 點擊選擇影片"),
                  ),
                ),
              )
            else
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black12,
                    child: Center(
                      child: Text(
                        // ✅ null-aware：pickedName 可能為 null（理論上不會，但 lint 友善）
                        "🎬 已選影片：${pickedName ?? ''}",
                        style: const TextStyle(color: Colors.pinkAccent),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: _uploading
                        ? null
                        : () => setState(() => _videoFile = null),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _descController,
              maxLines: 3,
              enabled: !_uploading,
              decoration: const InputDecoration(
                labelText: "影片描述",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.shopping_bag, color: Colors.pinkAccent),
              // ✅ 用 ?? 取代 null 比較 + !
              title: Text(_selectedProduct?["name"]?.toString() ?? "綁定商品（可選）"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _uploading ? null : _selectProduct,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _uploadVideo,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_uploading ? "上傳中..." : "上傳影片"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
