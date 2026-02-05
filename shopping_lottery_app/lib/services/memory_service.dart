// lib/services/memory_service.dart

/// MemoryService
/// 簡單的「最近對話 / 關鍵字記憶」工具：
/// - addMemory：寫入一筆文字記憶（會簡單清洗，只保留中英數與空白）
/// - recallRelated：根據新的查詢，從舊記憶中找出最相近的一筆（包含關係）
/// - lastMemory：取出最後一筆記憶
/// - clearMemory：清空所有記憶
class MemoryService {
  static final List<String> _memory = [];

  /// 新增一筆記憶文字，僅保留中英文與數字與空白
  /// 最多保留 5 筆，超過則移除最舊的一筆
  static void addMemory(String text) {
    final keywords = text
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9 ]'), '')
        .trim();

    if (keywords.isEmpty) return;

    if (_memory.length >= 5) {
      // 移除最舊記錄
      _memory.removeAt(0);
    }
    _memory.add(keywords);
  }

  /// 根據 newQuery 嘗試從記憶中找出「相關」的一筆：
  /// - 若 newQuery 包含舊記憶字串，或舊記憶包含 newQuery，則視為相關
  /// - 由最近的記憶往前找
  static String? recallRelated(String newQuery) {
    for (final old in _memory.reversed) {
      if (newQuery.contains(old) || old.contains(newQuery)) {
        return old;
      }
    }
    return null;
  }

  /// 取得最後一筆記憶，若沒有則回傳 null
  static String? lastMemory() =>
      _memory.isNotEmpty ? _memory.last : null;

  /// 清除所有記憶
  static void clearMemory() => _memory.clear();
}
