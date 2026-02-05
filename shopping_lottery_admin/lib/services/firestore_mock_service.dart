// lib/services/firestore_mock_service.dart
/// 簡單的本地 mock，供 LotteryService 在缺乏專屬後端時回退使用。
/// 你可以不用，如果你有完整後端就移除或替換。

class FirestoreMockService {
  FirestoreMockService._internal();
  static final FirestoreMockService instance = FirestoreMockService._internal();

  // 簡單狀態
  int userPoints = 0;

  Future<int> getPoints(String userId) async {
    // 模擬延遲
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return userPoints;
  }

  Future<void> addPoints(int value, {String? userId}) async {
    userPoints += value;
  }

  Future<bool> spendPoints(int value, {String? userId}) async {
    if (userPoints < value) return false;
    userPoints -= value;
    return true;
  }

  Future<void> deductPoints(int value, {String? userId}) async {
    userPoints = (userPoints - value).clamp(0, 1 << 30);
  }

  // fallback helpers used by LotteryService.resetPoints
  Future<void> setPoints(String userId, int value) async {
    userPoints = value;
  }

  Future<void> reset() async {
    userPoints = 0;
  }
}
