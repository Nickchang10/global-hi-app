import 'package:flutter/material.dart';
import 'notification_provider.dart';
import 'points_provider.dart';

/// 🧑‍🤝‍🧑 FriendProvider - 管理好友名單與邀請邏輯
class FriendProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _friends = [
    {
      "name": "Emily",
      "avatar": "https://i.pravatar.cc/150?img=3",
      "online": true,
    },
    {
      "name": "小志",
      "avatar": "https://i.pravatar.cc/150?img=4",
      "online": false,
    },
  ];

  final List<Map<String, dynamic>> _requests = [];

  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get requests => _requests;

  /// 發送好友邀請
  void sendFriendRequest(
      String name,
      BuildContext context,
      NotificationProvider notify,
      PointsProvider points) {
    _requests.add({
      "name": name,
      "avatar": "https://i.pravatar.cc/150?img=${30 + _requests.length}",
      "pending": true,
    });

    notify.addNotification("好友邀請", "你向 $name 發送了好友邀請 🤝");
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("已發送好友邀請給 $name")));

    notifyListeners();
  }

  /// 接受好友邀請
  void acceptRequest(
      Map<String, dynamic> request,
      BuildContext context,
      NotificationProvider notify,
      PointsProvider points) {
    _friends.add({
      "name": request["name"],
      "avatar": request["avatar"],
      "online": true,
    });

    _requests.remove(request);
    points.addPoints(10); // +10 積分
    notify.addNotification("好友新增", "你與 ${request['name']} 成為好友 🎉");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("你與 ${request['name']} 成為好友！ +10 積分")),
    );

    notifyListeners();
  }

  /// 拒絕好友邀請
  void declineRequest(Map<String, dynamic> request) {
    _requests.remove(request);
    notifyListeners();
  }
}
