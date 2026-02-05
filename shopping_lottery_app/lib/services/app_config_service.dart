import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AppConfigService extends ChangeNotifier {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  final _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('app_center');

  bool _initialized = false;
  bool get initialized => _initialized;

  // defaults
  bool shopHomeEnabled = true;
  bool bannerEnabled = true;
  bool bottomNavEnabled = true;
  bool featureToggleEnabled = true;
  bool sosHealthEnabled = true;
  bool deviceMgmtEnabled = true;

  void init() {
    _ref.snapshots().listen((snap) {
      final data = snap.data() ?? const <String, dynamic>{};

      shopHomeEnabled = data['shopHomeEnabled'] == true;
      bannerEnabled = data['bannerEnabled'] == true;
      bottomNavEnabled = data['bottomNavEnabled'] == true;
      featureToggleEnabled = data['featureToggleEnabled'] == true;
      sosHealthEnabled = data['sosHealthEnabled'] == true;
      deviceMgmtEnabled = data['deviceMgmtEnabled'] == true;

      _initialized = true;
      notifyListeners();
    }, onError: (_) {
      // 讀不到就維持 defaults，也標記已初始化避免卡 loading
      _initialized = true;
      notifyListeners();
    });
  }
}
