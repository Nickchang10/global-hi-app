import 'package:flutter/material.dart';

class CurrentPageService extends ChangeNotifier {
  String _currentPage = "unknown";
  String get currentPage => _currentPage;
  set currentPage(String page) => setPage(page);
  void setPage(String page) {
    if (_currentPage != page) {
      _currentPage = page;
      debugPrint("📍 CurrentPageService → 現在頁面：$_currentPage");
      notifyListeners();
    }
  }
  void setCurrentPage(String page) => setPage(page);
  bool isOn(String page) => _currentPage == page;
  String getSuggestion() {
    switch (_currentPage) {
      case "home": return "🎉 歡迎回到首頁～想看最新活動或新品預告嗎？";
      case "cart": return "🛒 您的購物車商品已準備好，是否要幫您套用最新折扣？";
      case "lottery": return "🍀 今天抽過獎了嗎？登入就能獲得一次免費機會喔！";
      case "live": return "📺 現正有商品直播中～要我幫您推薦人氣場次嗎？";
      case "social": return "💬 來看看其他用戶的開箱分享吧！";
      case "profile": return "👤 這是您的個人中心～可以查看積分與訂單紀錄。";
      case "product": return "📹 這是商品介紹頁，要不要幫您播放產品影片？";
      default: return "🤖 我隨時在這裡，可以幫您查詢活動、商品或折扣資訊。";
    }
  }
  String? getRecommendedVideo() {
    switch (_currentPage) {
      case "product": return "https://youtu.be/dQw4w9WgXcQ";
      case "live": return "https://www.youtube.com/live/demo";
      default: return null;
    }
  }
  void reset() {
    _currentPage = "unknown";
    notifyListeners();
  }
  @override
  String toString() => 'CurrentPageService(currentPage: $_currentPage)';
}
