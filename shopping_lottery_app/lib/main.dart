import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import 'firebase_bootstrap.dart';
import 'services/auth/auth_service.dart' as auth;

import 'pages/auth/auth_page.dart';
import 'pages/main_navigation_page.dart';

import 'pages/products/products_page.dart';
import 'pages/products/product_detail_page.dart';
import 'pages/cart/cart_page.dart';
import 'pages/checkout/checkout_page.dart';
import 'pages/tasks/tasks_page.dart';
import 'pages/member_page.dart';
import 'pages/lottery/lottery_page.dart';
import 'pages/activity_detail_page.dart';

// ✅ orders
import 'pages/orders/orders_page.dart';
import 'pages/orders/order_detail_page.dart';

// ✅ addresses / points
import 'pages/addresses/addresses_page.dart';
import 'pages/addresses/address_edit_page.dart';
import 'pages/points/points_page.dart';

// ✅ settings
import 'pages/settings/profile_settings_page.dart';
import 'pages/settings/shipping_settings_page.dart';
import 'pages/settings/notification_settings_page.dart';
import 'pages/settings/security_settings_page.dart';

// ✅ coupons
import 'pages/coupons/coupons_page.dart';

// ✅ notifications center
import 'pages/notifications/notifications_page.dart';

// ✅ video routes（新增）
import 'pages/videos/video_player_page.dart';
import 'pages/videos/videos_page.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        dev.log(
          'FlutterError: ${details.exceptionAsString()}',
          error: details.exception,
          stackTrace: details.stack,
          name: 'FlutterError',
        );
      };

      WidgetsFlutterBinding.ensureInitialized();
      await FirebaseBootstrap.ensureInitialized();
      runApp(const OsmileApp());
    },
    (error, stack) {
      dev.log(
        'Zone uncaught error: $error',
        error: error,
        stackTrace: stack,
        name: 'runZonedGuarded',
      );
    },
  );
}

class OsmileApp extends StatelessWidget {
  const OsmileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osmile Shopping',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const AuthGate(),
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: auth.AuthService.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) return const AuthPage();
        return const MainNavigationPage();
      },
    );
  }
}

String _norm(String? name) {
  var r = (name ?? '').trim();
  if (r.isEmpty) return '';
  while (r.endsWith('/') && r.length > 1) {
    r = r.substring(0, r.length - 1);
  }
  if (!r.startsWith('/')) r = '/$r';
  return r.toLowerCase();
}

Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final name = _norm(settings.name);
  final args = settings.arguments;

  late final Widget page;

  switch (name) {
    case '/shop':
    case '/products':
    case '/store':
      page = const ProductsPage();
      break;

    case '/product_detail':
    case '/productdetail':
    case '/product':
      final m = (args is Map) ? args : <String, dynamic>{};
      final pid = (m['productId'] ?? m['id'] ?? '').toString().trim();
      final prefill = (m['data'] is Map)
          ? Map<String, dynamic>.from(m['data'] as Map)
          : null;
      page = pid.isEmpty
          ? const _SimplePlaceholderPage(title: 'productId 缺失（請從列表帶 productId）')
          : ProductDetailPage(productId: pid, prefill: prefill);
      break;

    case '/cart':
      page = const CartPage();
      break;

    case '/checkout':
      page = CheckoutPage(args: args);
      break;

    case '/tasks':
    case '/task':
      page = const TasksPage();
      break;

    case '/lotterys':
    case '/lottery':
      page = const LotteryPage();
      break;

    case '/me':
    case '/member':
      page = const MemberPage();
      break;

    case '/activity_detail':
      page = ActivityDetailPage(args: args);
      break;

    case '/orders':
      page = const OrdersPage();
      break;

    case '/order_detail':
      final m = (args is Map) ? args : <String, dynamic>{};
      final orderId = (m['orderId'] ?? '').toString().trim();
      page = orderId.isEmpty
          ? const _SimplePlaceholderPage(title: 'orderId 缺失')
          : OrderDetailPage(orderId: orderId);
      break;

    case '/addresses':
      page = const AddressesPage();
      break;

    case '/address_edit':
      page = AddressEditPage(args: args);
      break;

    case '/points':
      page = const PointsPage();
      break;

    case '/settings/profile':
      page = const ProfileSettingsPage();
      break;

    case '/settings/shipping':
      page = const ShippingSettingsPage();
      break;

    case '/settings/notifications':
      page = const NotificationSettingsPage();
      break;

    case '/settings/security':
      page = const SecuritySettingsPage();
      break;

    case '/coupons':
      page = const CouponsPage();
      break;

    case '/notifications':
      page = const NotificationsPage();
      break;

    // ✅ 新增：影片播放 / 影片列表
    case '/video':
      page = VideoPlayerPage(args: args);
      break;

    case '/videos':
      page = const VideosPage();
      break;

    default:
      return null;
  }

  return MaterialPageRoute(builder: (_) => page, settings: settings);
}

class _SimplePlaceholderPage extends StatelessWidget {
  final String title;
  const _SimplePlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page')),
      body: Center(child: Text(title)),
    );
  }
}
