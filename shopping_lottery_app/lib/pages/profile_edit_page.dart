// lib/pages/profile_edit_page.dart
//
// ✅ ProfileEditPage（最終完整版｜已修正 FormField.value deprecated）
// ------------------------------------------------------------
// 你遇到的 warning：
//   "'value' is deprecated ... Use initialValue instead."
// 多半出現在：DropdownButtonFormField / FormField / TextFormField (某些用法)
// ✅ 修正策略：
// 1) TextFormField：用 controller（或 initialValue，但不能同時用）
// 2) DropdownButtonFormField：用 initialValue: xxx，不要再用 value: xxx
//
// 本頁提供：
// - 顯示/編輯：姓名、手機、生日、性別、地址、備註
// - 支援：讀取/寫入 Firestore users/{uid}
// - Web/App 可用
//
// 你只要整檔覆蓋即可編譯。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const Color _brand = Color(0xFF3B82F6);

  final _formKey = GlobalKey<FormState>();

  // Text fields use controller (避免用 initialValue + controller 同時存在)
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime? _birthday;
  String? _gender; // male/female/other/null

  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>>? _docRef;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  String _s(dynamic v) => v?.toString() ?? '';

  DateTime? _dt(dynamic v) {
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '未設定';
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y/$m/$day';
  }

  Future<void> _bootstrap() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      setState(() => _loading = false);
      return;
    }

    _docRef = FirebaseFirestore.instance.collection('users').doc(u.uid);

    try {
      final snap = await _docRef!.get();
      final data = snap.data() ?? {};

      _nameCtrl.text = _s(data['name']).trim();
      _phoneCtrl.text = _s(data['phone']).trim();
      _addressCtrl.text = _s(data['address']).trim();
      _noteCtrl.text = _s(data['note']).trim();

      _birthday = _dt(data['birthday']);
      final g = _s(data['gender']).trim().toLowerCase();
      _gender = g.isEmpty ? null : g;

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('讀取失敗：$e');
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final init = _birthday ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: '選擇生日',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _brand),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;
    if (!mounted) return;
    setState(() => _birthday = picked);
  }

  String? _vName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '請輸入姓名';
    if (s.length < 2) return '姓名至少 2 個字';
    return null;
  }

  String? _vPhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // optional
    final ok = RegExp(r'^[0-9+\-\s]{6,20}$').hasMatch(s);
    if (!ok) return '電話格式不正確';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final u = FirebaseAuth.instance.currentUser;
    if (u == null || _docRef == null) {
      _toast('請先登入');
      return;
    }

    setState(() => _saving = true);

    try {
      await _docRef!.set({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'birthday': _birthday == null ? null : Timestamp.fromDate(_birthday!),
        'gender': _gender,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _saving = false);
      _toast('已儲存');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('儲存失敗：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('編輯個人資料'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '儲存中…' : '儲存',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: u == null ? _needLogin() : (_loading ? _loadingView() : _form()),
    );
  }

  Widget _needLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('請先登入才能編輯個人資料', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/login'),
              child: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingView() {
    return const Center(child: CircularProgressIndicator.adaptive());
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
      children: [
        _card(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _fieldLabel('姓名'),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _dec(hint: '例如：王小明', icon: Icons.person_outline),
                  validator: _vName,
                ),
                const SizedBox(height: 12),

                _fieldLabel('手機 / 電話'),
                TextFormField(
                  controller: _phoneCtrl,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  decoration: _dec(
                    hint: '例如：0912-345-678',
                    icon: Icons.phone_outlined,
                  ),
                  validator: _vPhone,
                ),
                const SizedBox(height: 12),

                _fieldLabel('性別'),
                // ✅ 重點：DropdownButtonFormField 用 initialValue，不要用 value
                DropdownButtonFormField<String>(
                  initialValue: _gender, // ✅ 修正 deprecated value
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('男')),
                    DropdownMenuItem(value: 'female', child: Text('女')),
                    DropdownMenuItem(value: 'other', child: Text('其他')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                  decoration: _dec(hint: '選擇性別', icon: Icons.badge_outlined),
                ),
                const SizedBox(height: 12),

                _fieldLabel('生日'),
                InkWell(
                  onTap: _pickBirthday,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _fmtDate(_birthday),
                            style: TextStyle(
                              color: _birthday == null
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _fieldLabel('地址'),
                TextFormField(
                  controller: _addressCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _dec(
                    hint: '例如：台北市…',
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 12),

                _fieldLabel('備註'),
                TextFormField(
                  controller: _noteCtrl,
                  textInputAction: TextInputAction.done,
                  maxLines: 3,
                  decoration: _dec(
                    hint: '例如：常用收件資訊…',
                    icon: Icons.notes_outlined,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        _card(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _nameCtrl.clear();
                            _phoneCtrl.clear();
                            _addressCtrl.clear();
                            _noteCtrl.clear();
                            _birthday = null;
                            _gender = null;
                          });
                          _toast('已清除（尚未儲存）');
                        },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('清除'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('儲存'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
    );
  }

  InputDecoration _dec({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brand, width: 1.2),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
