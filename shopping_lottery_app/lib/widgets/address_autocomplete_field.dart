// lib/widgets/address_autocomplete_field.dart
import 'package:flutter/material.dart';

/// 範例版：單純顯示一個按鈕，實務上你可以整合 flutter_google_places / google_places_api 等套件
///
/// 使用方式：
/// AddressAutocompleteField(
///   initialText: _detail.text,
///   onAddressSelected: (text) { setState(() => _detail.text = text); },
/// )
class AddressAutocompleteField extends StatefulWidget {
  final String? initialText;
  final ValueChanged<String> onAddressSelected;

  const AddressAutocompleteField({
    super.key,
    this.initialText,
    required this.onAddressSelected,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
  }

  Future<void> _openPlacesSearch() async {
    // 這裡放你自己用 flutter_google_places 或其他套件打 Google Places API 的流程
    // 下面只是示範：假裝選到一個地址
    // final prediction = await PlacesAutocomplete.show(...);
    // final detail = await places.getDetailsByPlaceId(prediction.placeId);
    // final address = detail.result.formattedAddress;

    // demo：直接回寫假資料
    const demo = '台北市中正區重慶南路一段 100 號';
    setState(() {
      _ctrl.text = demo;
    });
    widget.onAddressSelected(demo);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: '詳細地址（可由地圖搜尋）',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.map_outlined),
          onPressed: _openPlacesSearch,
        ),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? '請選擇或輸入地址' : null,
      onTap: _openPlacesSearch,
    );
  }
}
