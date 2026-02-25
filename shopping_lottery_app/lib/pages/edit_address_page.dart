// lib/pages/edit_address_page.dart
import 'package:flutter/material.dart';
import 'taiwan_city_data.dart';
// 若要使用自動完成，就取消下面註解
// import '../widgets/address_autocomplete_field.dart';

class EditAddressPage extends StatefulWidget {
  final Map<String, dynamic>? data;

  const EditAddressPage({super.key, this.data});

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _detail;

  // 先給預設值，initState 會依 data 修正
  String _selectedCity = "台北市";
  String _selectedDistrict = "中正區";

  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data;

    _title = TextEditingController(text: (d?['title'] ?? '').toString());
    _name = TextEditingController(text: (d?['name'] ?? '').toString());
    _phone = TextEditingController(text: (d?['phone'] ?? '').toString());
    _detail = TextEditingController(text: (d?['detail'] ?? '').toString());

    // --- 縣市/區域安全初始化（避免 value 不存在於 items 而爆掉） ---
    final cities = taiwanCityData.keys.toList();
    final incomingCity = (d?['city'] ?? _selectedCity).toString();
    _selectedCity = cities.contains(incomingCity)
        ? incomingCity
        : (cities.isNotEmpty ? cities.first : "台北市");

    final districts = taiwanCityData[_selectedCity] ?? <String>[];
    final incomingDistrict = (d?['district'] ?? _selectedDistrict).toString();
    _selectedDistrict = districts.contains(incomingDistrict)
        ? incomingDistrict
        : (districts.isNotEmpty ? districts.first : _selectedDistrict);

    _isDefault = (d?['isDefault'] == true);
  }

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _phone.dispose();
    _detail.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return '請輸入手機號碼';
    // 很粗略的台灣手機檢查：09 開頭 + 10 碼
    if (!RegExp(r'^09\d{8}$').hasMatch(text)) {
      return '請輸入正確手機號碼（例如：0912345678）';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final fullAddress =
        "$_selectedCity$_selectedDistrict${_detail.text.trim()}";

    Navigator.pop(context, {
      "title": _title.text.trim(),
      "name": _name.text.trim(),
      "phone": _phone.text.trim(),
      "city": _selectedCity,
      "district": _selectedDistrict,
      "detail": _detail.text.trim(),
      "fullAddress": fullAddress,
      "isDefault": _isDefault,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cityList = taiwanCityData.keys.toList();
    final districts = taiwanCityData[_selectedCity] ?? <String>[];

    // 再保險一次：如果縣市變更造成區域不存在，保證 UI 不會爆
    final safeCity = cityList.contains(_selectedCity)
        ? _selectedCity
        : (cityList.isNotEmpty ? cityList.first : _selectedCity);
    final safeDistrict = districts.contains(_selectedDistrict)
        ? _selectedDistrict
        : (districts.isNotEmpty ? districts.first : _selectedDistrict);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data == null ? "新增地址" : "編輯地址"),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.check))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: "標籤（家、公司…）",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? "請輸入標籤名稱" : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: "收件人姓名",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? "請輸入收件人姓名" : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "手機號碼",
                  border: OutlineInputBorder(),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 20),

              // ✅ 修正：value -> initialValue（避免 deprecated_member_use）
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'city_$safeCity',
                ), // 避免 initialValue 因 rebuild 不更新造成怪狀態
                initialValue: safeCity,
                decoration: const InputDecoration(
                  labelText: "縣市",
                  border: OutlineInputBorder(),
                ),
                items: cityList
                    .map(
                      (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedCity = v;
                    final newDistricts =
                        taiwanCityData[_selectedCity] ?? <String>[];
                    _selectedDistrict = newDistricts.isNotEmpty
                        ? newDistricts.first
                        : _selectedDistrict;
                  });
                },
              ),
              const SizedBox(height: 14),

              // ✅ 修正：value -> initialValue（避免 deprecated_member_use）
              DropdownButtonFormField<String>(
                key: ValueKey('district_${_selectedCity}_$safeDistrict'),
                initialValue: safeDistrict,
                decoration: const InputDecoration(
                  labelText: "鄉鎮／區",
                  border: OutlineInputBorder(),
                ),
                items: districts
                    .map(
                      (d) => DropdownMenuItem<String>(value: d, child: Text(d)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedDistrict = v);
                },
              ),
              const SizedBox(height: 14),

              // 若要 Google 自動完成，可改成 AddressAutocompleteField：
              /*
              AddressAutocompleteField(
                initialText: _detail.text,
                onAddressSelected: (text) {
                  setState(() {
                    _detail.text = text;
                  });
                },
              ),
              */
              TextFormField(
                controller: _detail,
                decoration: const InputDecoration(
                  labelText: "詳細地址（路名、巷弄、門牌樓層…）",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? "請輸入詳細地址" : null,
              ),
              const SizedBox(height: 20),

              SwitchListTile(
                title: const Text("設為預設地址"),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
