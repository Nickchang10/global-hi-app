// lib/pages/edit_profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// ✏️ 帳號設定 / 編輯個人資料頁
///
/// 功能：
/// ✅ 更改暱稱  
/// ✅ 更換頭像（相簿 / 拍照）  
/// ✅ 預覽變更  
/// ✅ 回傳更新資料
class EditProfilePage extends StatefulWidget {
  final String username;
  final String? avatarPath;

  const EditProfilePage({
    super.key,
    required this.username,
    this.avatarPath,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameCtrl;
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.username);
    _avatar = widget.avatarPath;
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _avatar = picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("帳號設定"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {
                "username": _nameCtrl.text.trim(),
                "avatar": _avatar,
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _showAvatarOptions(context),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blueAccent,
                backgroundImage:
                    _avatar != null ? FileImage(File(_avatar!)) : null,
                child: _avatar == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "暱稱",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "點擊頭像可更換照片，修改完成後請按右上角 ✅ 儲存",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("從相簿選取"),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("拍照上傳"),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("移除頭像"),
              onTap: () {
                setState(() => _avatar = null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
