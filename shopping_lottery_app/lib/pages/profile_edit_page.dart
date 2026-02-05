// lib/pages/profile_edit_page.dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Conditional import helpers:
// if running on web, the html implementation will be used; otherwise the stub returns null.
import 'package:osmile_shopping_app/utils/file_picker_stub.dart'
    if (dart.library.html) 'package:osmile_shopping_app/utils/file_picker_html.dart';

import 'package:osmile_shopping_app/services/firestore_mock_service.dart';
import 'package:osmile_shopping_app/services/auth_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String? _email;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.userId ?? 'current_user';
    final profile = FirestoreMockService.instance.getUserProfile(uid) ?? {};
    _name = profile['name']?.toString();
    _email = profile['email']?.toString();
    _avatarUrl = profile['avatarUrl']?.toString();
  }

  Future<void> _pickAvatar() async {
    // Only web implementation returns bytes; stub on other platforms returns null.
    final bytes = await pickImageFileWeb();
    if (bytes == null) {
      if (!kIsWeb) {
        // On non-web, fallback to asking for URL
        final url = await _askForUrl();
        if (url != null) {
          setState(() {
            _avatarUrl = url;
            _avatarBytes = null;
          });
        }
      }
      return;
    }
    setState(() {
      _avatarBytes = bytes;
      _avatarUrl = null;
    });
  }

  Future<String?> _askForUrl() async {
    final ctrl = TextEditingController(text: _avatarUrl ?? '');
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('輸入圖片網址'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'https://...')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('確定')),
        ],
      ),
    );
    return res;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);
    final uid = AuthService.instance.userId ?? 'current_user';
    final prof = FirestoreMockService.instance.getUserProfile(uid) ?? {};
    prof['name'] = _name;
    prof['email'] = _email;
    if (_avatarBytes != null) {
      // convert to base64 data URL and store in profile (for demo)
      final base64Str = base64Encode(_avatarBytes!);
      final dataUrl = 'data:image/png;base64,$base64Str';
      prof['avatarBase64'] = dataUrl;
      prof.remove('avatarUrl');
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      prof['avatarUrl'] = _avatarUrl;
      prof.remove('avatarBase64');
    }
    await FirestoreMockService.instance.setUserProfile(uid, prof);
    setState(() => _loading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存（模擬）')));
    Navigator.of(context).pop();
  }

  Widget _avatarPreview() {
    if (_avatarBytes != null) {
      return CircleAvatar(radius: 48, backgroundImage: MemoryImage(_avatarBytes!));
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CircleAvatar(radius: 48, backgroundImage: NetworkImage(_avatarUrl!));
    }
    final uid = AuthService.instance.userId ?? 'U';
    final profile = FirestoreMockService.instance.getUserProfile(uid) ?? {};
    final name = profile['name'] ?? 'U';
    return CircleAvatar(radius: 48, backgroundColor: Colors.blueAccent, child: Text(name.toString().isNotEmpty ? name.toString()[0] : 'U', style: const TextStyle(color: Colors.white, fontSize: 28)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯資料'),
        actions: [
          TextButton(onPressed: _save, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('儲存', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            Center(child: _avatarPreview()),
            const SizedBox(height: 8),
            Center(
              child: Wrap(spacing: 8, children: [
                ElevatedButton.icon(onPressed: _pickAvatar, icon: const Icon(Icons.camera_alt), label: const Text('上傳/選擇')),
                OutlinedButton.icon(onPressed: () async {
                  final url = await _askForUrl();
                  if (url != null) {
                    setState(() {
                      _avatarUrl = url;
                      _avatarBytes = null;
                    });
                  }
                }, icon: const Icon(Icons.link), label: const Text('使用圖片網址')),
              ]),
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(labelText: '名稱'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入名稱' : null,
              onSaved: (v) => _name = v?.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入 Email' : null,
              onSaved: (v) => _email = v?.trim(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('儲存')),
            const SizedBox(height: 20),
            if (!kIsWeb) const Text('提示：桌面/行動平台請使用「使用圖片網址」或在未來安裝平台專屬上傳套件。', style: TextStyle(color: Colors.black54)),
          ]),
        ),
      ),
    );
  }
}
