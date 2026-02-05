// lib/services/story_service.dart
import 'package:flutter/material.dart';

class StoryService extends ChangeNotifier {
  StoryService._internal();
  static final StoryService instance = StoryService._internal();

  final List<Map<String, dynamic>> _stories = [];

  List<Map<String, dynamic>> get stories => List.unmodifiable(_stories);

  void addStory(Map<String, dynamic> s) {
    _stories.insert(0, s);
    notifyListeners();
  }
}
