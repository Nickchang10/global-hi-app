# global-hi-app

Osmile / global-hi-app

此 repository 包含多個 Flutter 子專案（示範 App 與後台管理端），目標為展示購物、健康、支付與追蹤等整合功能。

子專案
- shopping_lottery_app/ — Osmile 示範購物 App（mobile / web）
- shopping_lottery_admin/ — Osmile 後台管理系統（admin）

快速上手
1. 安裝必要工具
   - Flutter SDK >= 3.10
   - Android Studio / Xcode（若要在 iOS）
   - Node/npm（若需要）

2. 取得程式碼
```bash
git clone https://github.com/Nickchang10/global-hi-app.git
cd global-hi-app
git checkout -b release-ready
```

3. 安裝相依套件（每個子專案分別執行）
```bash
cd shopping_lottery_app
flutter pub get
cd ../shopping_lottery_admin
flutter pub get
```

自動檢查與測試（本機）
```bash
# 在 repo root
flutter format --set-exit-if-changed .
dart fix --apply
flutter analyze
flutter test || true
```

建置 Release（測試）
```bash
# Android AAB
cd shopping_lottery_app
flutter build appbundle --release

# iOS (需 macOS 與經過簽章設定)
flutter build ipa --release
```

上架必備（你需要提供）
- Android keystore (.jks) 與 key.properties（不要提交密碼至 repo）
- iOS certificates / provisioning profiles / Apple Team ID
- App icons、啟動畫面與隱私政策 URL

更多細節請查看 root 的 checklist.md（已新增）。