// lib/services/card_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardModel {
  final String id;
  final String holder;
  final String numberMasked;
  final String brand;
  CardModel({required this.id, required this.holder, required this.numberMasked, required this.brand});
  Map<String, dynamic> toMap() => {'id': id, 'holder': holder, 'numberMasked': numberMasked, 'brand': brand};
  factory CardModel.fromMap(Map<String, dynamic> m) => CardModel(id: m['id'] ?? '', holder: m['holder'] ?? '', numberMasked: m['numberMasked'] ?? '', brand: m['brand'] ?? '');
}

class CardService extends ChangeNotifier {
  CardService._internal();
  static final CardService instance = CardService._internal();

  static const String _kKey = 'osmile_cards_v1';
  final List<CardModel> _cards = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey) ?? '';
    if (raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _cards.clear();
        for (final e in list) if (e is Map) _cards.add(CardModel.fromMap(Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    notifyListeners();
  }

  List<CardModel> get cards => List.unmodifiable(_cards);

  Future<void> addCard(CardModel c) async {
    _cards.add(c);
    await _save();
    notifyListeners();
  }

  Future<void> removeCard(String id) async {
    _cards.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cards.map((c) => c.toMap()).toList();
    await prefs.setString(_kKey, jsonEncode(list));
  }

  Future<void> clear() async {
    _cards.clear();
    await _save();
    notifyListeners();
  }
}
