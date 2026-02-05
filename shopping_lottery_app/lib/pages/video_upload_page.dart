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
      builder: (_) => Container(
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
                  Navigator.pop(context);
                  setState(() => _selectedProduct = p);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _uploadVideo() {
    if (_videoFile == null || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("請選擇影片並輸入描述")),
      );
      return;
    }

    // 模擬上傳
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("上傳中... 🚀")),
    );

    Future.delayed(const Duration(seconds: 2), () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("影片上傳成功 ✅")),
      );
      Navigator.pop(context, {
        "url": _videoFile!.path,
        "desc": _descController.text,
        "product": _selectedProduct,
        "likes": 0,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("上傳短影片"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _videoFile == null
                ? GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Text("📹 點擊選擇影片"),
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.black12,
                        child: Center(
                          child: Text(
                            "🎬 已選影片：${_videoFile!.path.split('/').last}",
                            style: const TextStyle(color: Colors.pinkAccent),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => setState(() => _videoFile = null),
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "影片描述",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.shopping_bag, color: Colors.pinkAccent),
              title: Text(_selectedProduct == null
                  ? "綁定商品（可選）"
                  : _selectedProduct!["name"]),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _selectProduct,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _uploadVideo,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("上傳影片"),
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
