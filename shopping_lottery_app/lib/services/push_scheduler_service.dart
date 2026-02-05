import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class PushSchedulerService extends ChangeNotifier {
  PushSchedulerService._internal();
  static final PushSchedulerService instance = PushSchedulerService._internal();

  void simulateDailyPush() {
    NotificationService.instance.addNotification(
      title: "📅 每日優惠",
      message: "今日限定折扣 10%，快來看看吧！",
    );
  }
}
