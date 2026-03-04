import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'store_page/state/app_state.dart' as store_app;

import 'firebase_bootstrap.dart';
import 'services/auth/auth_service.dart' as auth;

import 'pages/auth/auth_page.dart';
import 'pages/main_navigation_page.dart';

import 'pages/products/products_page.dart';

// import new store product detail page
import 'store_page/pages/product_detail_page.dart' as store_product;
// store search page
import 'store_page/pages/search_page.dart' as store_search;
// store orders page (new UI)
import 'store_page/pages/orders_page.dart' as store_orders;
// store cart page (new UI)
import 'store_page/pages/cart_page.dart' as store_cart;
// store checkout page (simple in-store flow)
import 'store_page/pages/checkout_page.dart' as store_checkout;
// store lottery page (new UI)
import 'store_page/pages/lottery_detail_page.dart' as store_lottery;
import 'store_page/pages/lottery_reveal_page.dart' as store_lottery_reveal;
// store shop page (store detail)
import 'store_page/pages/store_page.dart' as store_shop;
import 'store_page/pages/lottery_history_page.dart' as store_lottery_history;
import 'pages/cart/cart_page.dart';
import 'pages/checkout/checkout_page.dart';
import 'pages/tasks/tasks_page.dart';
import 'pages/member_page.dart';
import 'pages/lottery/lottery_page.dart';
import 'pages/activity_detail_page.dart';

// ✅ orders
import 'pages/orders/orders_page.dart';
import 'pages/orders/order_detail_page.dart';
import 'pages/orders/order_success_page.dart';

// ✅ payment（前端金流流程）
import 'pages/payment/payment_page.dart';
import 'pages/payment/payment_status_page.dart';

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

// ✅ video routes
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
    return ChangeNotifierProvider<store_app.AppState>(
      create: (_) => store_app.AppState(),
      child: MaterialApp(
        title: 'Osmile Shopping',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const AuthGate(),
        onGenerateRoute: _onGenerateRoute,
      ),
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
    // ✅ 給 OrderSuccessPage 回首頁用
    case '/home':
    case '/':
      page = const AuthGate();
      break;

    case '/shop':
    case '/products':
    case '/store':
      page = const ProductsPage();
      break;

    case '/search':
      page = const store_search.SearchPage();
      break;

    case '/product_detail':
    case '/productdetail':
    case '/product':
      final m = (args is Map) ? args : <String, dynamic>{};
      final pid = (m['productId'] ?? m['id'] ?? '').toString().trim();
      if (pid.isEmpty) {
        page = const _SimplePlaceholderPage(title: 'productId 缺失（請從列表帶 productId）');
      } else {
        // Use new store_page ProductDetailPage with Firestore data
        page = store_product.ProductDetailPage(id: pid);
      }
      break;

    case '/cart':
      page = const CartPage();
      break;

    case '/store_cart':
      page = const store_cart.CartPage();
      break;

    case '/store_checkout':
      page = const store_checkout.CheckoutPage();
      break;

    case '/checkout':
      page = CheckoutPage(args: args);
      break;

    // ✅ 前端金流流程：付款頁
    case '/payment':
      page = PaymentPage(args: args);
      break;

    case '/store_payment':
      page = PaymentPage(args: args);
      break;

    // ✅ 前端金流流程：付款狀態監聽頁
    case '/payment_status':
      page = PaymentStatusPage(args: args);
      break;

    // ✅ 下單成功頁
    case '/order_success':
      String? orderId;
      num? amount;
      int autoBackSeconds = 0;

      if (args is Map) {
        orderId = args['orderId']?.toString();
        final a = args['amount'];
        if (a is num) amount = a;
        final s = args['autoBackSeconds'];
        if (s is int) autoBackSeconds = s;
      }

      page = OrderSuccessPage(
        orderId: orderId,
        amount: amount,
        autoBackSeconds: autoBackSeconds,
      );
      break;

    case '/tasks':
    case '/task':
      page = const TasksPage();
      break;

    case '/lotterys':
    case '/lottery':
      page = const LotteryPage();
      break;

    case '/store_lottery':
      final m = (args is Map) ? args : <String, dynamic>{};
      final lotteryId = (m['id'] ?? m['lotteryId'] ?? '').toString().trim();
      page = lotteryId.isEmpty
          ? const _SimplePlaceholderPage(title: 'lotteryId 缺失')
          : store_lottery.LotteryDetailPage(id: lotteryId);
      break;

    case '/store_lottery_history':
      final m = (args is Map) ? args : <String, dynamic>{};
      final lotteryId = (m['id'] ?? m['lotteryId'] ?? '').toString().trim();
      page = store_lottery_history.LotteryHistoryPage(lotteryId: lotteryId.isEmpty ? null : lotteryId);
      break;

    case '/lottery-reveal':
      final m = (args is Map) ? args : <String, dynamic>{};
      final lotteryId = (m['id'] ?? m['lotteryId'] ?? '').toString().trim();
      page = lotteryId.isEmpty
          ? const _SimplePlaceholderPage(title: 'lotteryId 缺失')
          : store_lottery_reveal.LotteryRevealPage(id: lotteryId);
      break;

    case '/store_shop':
      final m = (args is Map) ? args : <String, dynamic>{};
      final storeId = (m['id'] ?? m['storeId'] ?? '').toString().trim();
      page = storeId.isEmpty
          ? const _SimplePlaceholderPage(title: 'storeId 缺失')
          : store_shop.StorePage(id: storeId);
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

    case '/store_orders':
      page = const store_orders.OrdersPage();
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
