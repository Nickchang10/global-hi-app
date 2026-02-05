// lib/services/address_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddressService {
  final String baseUrl;

  AddressService({this.baseUrl = 'https://api.example.com'});

  Future<List<Map<String, dynamic>>> fetchAddresses() async {
    final url = Uri.parse('$baseUrl/addresses');
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Server error: ${res.statusCode}');
    }

    final List data = json.decode(res.body) as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> payload) async {
    final url = Uri.parse('$baseUrl/addresses');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Create failed: ${res.statusCode}');
    }

    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAddress(Map<String, dynamic> payload) async {
    // 預設假設 payload 裡有 id
    final id = payload['id'];
    final url = Uri.parse('$baseUrl/addresses/$id');
    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.statusCode}');
    }

    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteAddress(dynamic id) async {
    final url = Uri.parse('$baseUrl/addresses/$id');
    final res = await http.delete(url);

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Delete failed: ${res.statusCode}');
    }
  }
}
