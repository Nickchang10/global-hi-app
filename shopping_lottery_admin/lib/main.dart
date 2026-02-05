// lib/main.dart
//
// ✅ OsmileAdminApp（路線 A｜最終完整版｜補齊 /admin_sales_report /admin_sales_export｜補齊 /admin/coupons/edit｜避免 Unknown route）
// ------------------------------------------------------------
// ✅ 本版已「接上正式優惠券頁」：
//   - /admin/coupons        -> AdminCouponsPage
//   - /admin/coupons/edit   -> AdminCouponEditPage（支援新增/編輯）
// ------------------------------------------------------------

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

// Controllers
import 'controllers/admin_mode_controller.dart';
import 'controllers/locale_controller.dart';

// Services
import 'services/auth_service.dart';
import 'services/admin_gate.dart';
import 'services/product_service.dart';
import 'services/category_service.dart';
import 'services/vendor_service.dart';
import 'services/app_config_service.dart';
import 'services/announcement_service.dart';
import 'services/task_template_service.dart';
import 'services/order_service.dart';
import 'services/order_create_service.dart';
import 'services/coupon_service.dart';
import 'services/payment_service.dart';
import 'services/lottery_service.dart';
import 'services/user_doc_service.dart';
import 'services/notification_service.dart';

// Pages
import 'pages/login_page.dart' as login_page;
import 'pages/admin/admin_shell_page.dart' as shell_page;

// 報表模組
import 'pages/admin/reports/admin_reports_dashboard_page.dart'
    as admin_reports_dashboard_page;

// ✅ 營收報表 / 匯出
import 'pages/admin/reports/admin_sales_report_page.dart'
    as admin_sales_report_page;
import 'pages/admin/reports/admin_sales_export_page.dart'
    as admin_sales_export_page;

// 通知中心
import 'pages/notifications_page.dart' as notifications_page;

// 廠商管理
import 'pages/admin/vendors/admin_vendors_page.dart' as admin_vendors_page;
import 'pages/admin/vendors/admin_vendors_dashboard_page.dart'
    as admin_vendors_dashboard_page;
import 'pages/admin/vendors/admin_vendor_detail_page.dart'
    as admin_vendor_detail_page;
import 'pages/admin/vendors/admin_vendors_report_page.dart'
    as admin_vendors_report_page;

// 活動中心
import 'pages/admin/campaigns/admin_campaigns_page.dart'
    as admin_campaigns_page;
import 'pages/admin/campaigns/admin_campaign_edit_page.dart'
    as admin_campaign_edit_page;

// ✅ ✅ ✅ 優惠券（正式頁面）
// - /admin/coupons        -> AdminCouponsPage
// - /admin/coupons/edit   -> AdminCouponEditPage
import 'pages/admin/marketing/admin_coupons_page.dart' as admin_coupons_page;
import 'pages/admin/marketing/admin_coupon_edit_page.dart'
    as admin_coupon_edit_page;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      // ignore: avoid_print
      print('Firebase initialized');
    }
  } catch (e, st) {
    runApp(FirebaseInitErrorApp(error: '$e\n$st'));
    return;
  }

  Provider.debugCheckInvalidValueType = null;

  final localeController = LocaleController();
  await localeController.ensureLoaded();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminModeController()),
        ChangeNotifierProvider(create: (_) => AdminGate()),
        ChangeNotifierProvider<LocaleController>.value(value: localeController),

        // Services
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => ProductService()),
        Provider(create: (_) => CategoryService()),
        Provider(create: (_) => VendorService()),
        Provider(create: (_) => AppConfigService()),
        Provider(create: (_) => AnnouncementService()),
        Provider(create: (_) => TaskTemplateService()),
        Provider(create: (_) => OrderService()),
        Provider(create: (_) => OrderCreateService()),
        Provider(create: (_) => CouponService()),
        Provider(create: (_) => PaymentService()),
        Provider(create: (_) => LotteryService()),
        Provider(create: (_) => UserDocService()),
        ChangeNotifierProvider(
          create: (_) => NotificationService(enableDebugLog: kDebugMode),
        ),
      ],
      child: const OsmileAdminApp(),
    ),
  );
}

class OsmileAdminApp extends StatelessWidget {
  const OsmileAdminApp({super.key});

  // ------------------------------------------------------------
  // Route helpers（支援 web hash / query / path segments）
  // ------------------------------------------------------------

  Uri _normalizeToUri(String raw) {
    final trimmed = raw.trim();

    // ✅ 只要有 '#', 就優先使用 '#' 後的內容當作實際路徑（解決 Web hash / fragment）
    String effective = trimmed;
    final hashIndex = trimmed.indexOf('#');
    if (hashIndex != -1) {
      effective = trimmed.substring(hashIndex + 1);
      if (effective.isEmpty) effective = '/';
    }

    if (effective.startsWith('#')) {
      effective = effective.substring(1);
      if (effective.isEmpty) effective = '/';
    }

    return Uri.tryParse(effective) ?? Uri(path: effective);
  }

  String _normalizePath(Uri uri) {
    final p = (uri.path.isEmpty ? '/' : uri.path).trim();
    final noTrailing =
        (p.length > 1 && p.endsWith('/')) ? p.substring(0, p.length - 1) : p;
    return noTrailing.startsWith('/') ? noTrailing : '/$noTrailing';
  }

  String _argMapString(Object? args, String key) {
    if (args is Map && args[key] != null) return args[key].toString();
    return '';
  }

  // =========================
  // vendorId helper
  // =========================
  String _vendorIdFrom(Object? args, Uri uri) {
    if (args is String && args.trim().isNotEmpty) return args.trim();

    final v1 = _argMapString(args, 'vendorId');
    if (v1.trim().isNotEmpty) return v1.trim();

    final v2 = _argMapString(args, 'id');
    if (v2.trim().isNotEmpty) return v2.trim();

    final q1 = (uri.queryParameters['vendorId'] ?? '').trim();
    if (q1.isNotEmpty) return q1;

    final q2 = (uri.queryParameters['id'] ?? '').trim();
    if (q2.isNotEmpty) return q2;

    final seg = uri.pathSegments;
    if (seg.length >= 3 &&
        seg[0] == 'admin_vendors' &&
        (seg[1] == 'detail' || seg[1] == 'report' || seg[1] == 'edit')) {
      final s = seg[2].trim();
      if (s.isNotEmpty) return s;
    }

    return '';
  }

  String _vendorNameFrom(Object? args, Uri uri) {
    final a = _argMapString(args, 'vendorName').trim();
    if (a.isNotEmpty) return a;

    final q = (uri.queryParameters['vendorName'] ?? '').trim();
    if (q.isNotEmpty) return q;

    return '';
  }

  // =========================
  // ✅ couponId helper
  // =========================
  String _couponIdFrom(Object? args, Uri uri) {
    // 1) arguments String
    if (args is String && args.trim().isNotEmpty) return args.trim();

    // 2) arguments Map['couponId'] or Map['id']
    final c1 = _argMapString(args, 'couponId');
    if (c1.trim().isNotEmpty) return c1.trim();

    final c2 = _argMapString(args, 'id'); // 相容舊 key
    if (c2.trim().isNotEmpty) return c2.trim();

    // 3) query ?couponId= / ?id=
    final q1 = (uri.queryParameters['couponId'] ?? '').trim();
    if (q1.isNotEmpty) return q1;

    final q2 = (uri.queryParameters['id'] ?? '').trim();
    if (q2.isNotEmpty) return q2;

    // 4) path segment：/admin/coupons/edit/<id>
    final seg = uri.pathSegments;
    // segments: ['admin','coupons','edit','<id>']
    if (seg.length >= 4 &&
        seg[0] == 'admin' &&
        seg[1] == 'coupons' &&
        seg[2] == 'edit') {
      final s = seg[3].trim();
      if (s.isNotEmpty) return s;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final localeCtrl = context.watch<LocaleController>();

    return MaterialApp(
      title: 'Osmile 後台管理系統',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      locale: localeCtrl.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const AuthRouter(),

      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '/';
        final uri = _normalizeToUri(rawName);
        final path = _normalizePath(uri);
        final args = settings.arguments;

        // =========================================================
        // vendor: detail/report/edit
        // =========================================================

        if (path == '/admin_vendors/detail' ||
            path.startsWith('/admin_vendors/detail/')) {
          final vendorId = _vendorIdFrom(args, uri);

          if (vendorId.isEmpty) {
            return MaterialPageRoute(
              builder: (_) => const _MissingArgPage(
                title: '缺少參數',
                message:
                    '此頁面需要 vendorId。\n請從「廠商列表」點入，或帶入 arguments/query/path。',
              ),
            );
          }

          return MaterialPageRoute(
            builder: (_) => admin_vendor_detail_page.AdminVendorDetailPage(
              vendorId: vendorId,
            ),
          );
        }

        if (path == '/admin_vendors/report' ||
            path.startsWith('/admin_vendors/report/')) {
          final vendorId = _vendorIdFrom(args, uri);
          final vendorName = _vendorNameFrom(args, uri);

          if (vendorId.isEmpty) {
            return MaterialPageRoute(
              builder: (_) => const _MissingArgPage(
                title: '缺少參數',
                message: '此頁面需要 vendorId。\n請從「廠商列表」或「廠商儀表板」點入。',
              ),
            );
          }

          return MaterialPageRoute(
            builder: (_) => admin_vendors_report_page.AdminVendorReportPage(
              vendorId: vendorId,
              vendorName: vendorName,
            ),
          );
        }

        if (path == '/admin_vendors/edit' ||
            path.startsWith('/admin_vendors/edit/')) {
          final vendorId = _vendorIdFrom(args, uri);

          Map<String, dynamic>? initialData;
          if (args is Map) {
            final d = args['data'];
            if (d is Map<String, dynamic>) initialData = d;
            if (initialData == null) {
              try {
                initialData = Map<String, dynamic>.from(args);
              } catch (_) {}
            }
          }

          return MaterialPageRoute(
            builder: (_) => _VendorEditPlaceholderPage(
              vendorId: vendorId.isEmpty ? null : vendorId,
              initialData: initialData,
            ),
          );
        }

        // =========================================================
        // sales report/export（switch 前攔截）
        // =========================================================
        if (path == '/admin_sales_report' ||
            path.startsWith('/admin_sales_report/')) {
          return MaterialPageRoute(
            builder: (_) =>
                const admin_sales_report_page.AdminSalesReportPage(),
          );
        }

        if (path == '/admin_sales_export' ||
            path.startsWith('/admin_sales_export/')) {
          return MaterialPageRoute(
            builder: (_) =>
                const admin_sales_export_page.AdminSalesExportPage(),
          );
        }

        // =========================================================
        // ✅ ✅ ✅ Coupons（正式接上頁面）
        // =========================================================

        // ✅ 優惠券編輯/新增：/admin/coupons/edit 或 /admin/coupons/edit/<id>
        if (path == '/admin/coupons/edit' ||
            path.startsWith('/admin/coupons/edit/')) {
          final couponId = _couponIdFrom(args, uri);

          return MaterialPageRoute(
            builder: (_) => admin_coupon_edit_page.AdminCouponEditPage(
              couponId: couponId.isEmpty ? null : couponId,
            ),
          );
        }

        // ✅ 優惠券列表：/admin/coupons
        if (path == '/admin/coupons' || path.startsWith('/admin/coupons/')) {
          return MaterialPageRoute(
            builder: (_) => const admin_coupons_page.AdminCouponsPage(),
          );
        }

        // =========================================================
        // 一般路由 switch
        // =========================================================
        switch (path) {
          case '/':
            return MaterialPageRoute(builder: (_) => const AuthRouter());

          case '/login':
            return MaterialPageRoute(
              builder: (_) => const login_page.LoginPage(),
            );

          case '/register':
            return MaterialPageRoute(
              builder: (_) => const _RegisterPlaceholderPage(),
            );

          case '/dashboard':
            return MaterialPageRoute(
              builder: (_) => const shell_page.AdminShellPage(),
            );

          case '/admin_reports_dashboard':
            return MaterialPageRoute(
              builder: (_) => const admin_reports_dashboard_page
                  .AdminReportsDashboardPage(),
            );

          case '/notifications':
            return MaterialPageRoute(
              builder: (_) => const notifications_page.NotificationsPage(),
            );

          case '/admin_vendors':
            return MaterialPageRoute(
              builder: (_) => const admin_vendors_page.AdminVendorsPage(),
            );

          case '/admin_vendors/dashboard':
            return MaterialPageRoute(
              builder: (_) => const admin_vendors_dashboard_page
                  .AdminVendorsDashboardPage(),
            );

          case '/admin_campaigns':
            return MaterialPageRoute(
              builder: (_) => const admin_campaigns_page.AdminCampaignsPage(),
            );

          case '/admin_campaigns/edit':
            return MaterialPageRoute(
              builder: (_) =>
                  const admin_campaign_edit_page.AdminCampaignEditPage(),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => _UnknownRoutePage(routeName: rawName),
            );
        }
      },
    );
  }
}

// =======================================================
// Auth Router
// =======================================================

class AuthRouter extends StatefulWidget {
  const AuthRouter({super.key});

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  bool _didNavigate = false;

  Future<String> _getUserRole(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return (doc.data()?['role'] ?? 'admin').toString();
    } catch (_) {
      return 'admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeController = context.read<AdminModeController>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;

        if (user == null) {
          _didNavigate = false;
          modeController.clearPersisted();
          return const login_page.LoginPage();
        }

        return FutureBuilder<String>(
          future: _getUserRole(user.uid),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            modeController.setRole(roleSnap.data!);

            if (!_didNavigate) {
              _didNavigate = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/dashboard');
              });
            }

            return const Scaffold(
              body: Center(child: Text('登入成功，正在進入後台...')),
            );
          },
        );
      },
    );
  }
}

// =======================================================
// Placeholder Pages
// =======================================================

class _RegisterPlaceholderPage extends StatelessWidget {
  const _RegisterPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 44),
                const SizedBox(height: 10),
                const Text(
                  '註冊頁尚未接入',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  '目前先用占位頁避免 Unknown route。\n你之後接上正式 RegisterPage 時，只要替換 /register 路由即可。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('回登入'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorEditPlaceholderPage extends StatelessWidget {
  final String? vendorId;
  final Map<String, dynamic>? initialData;

  const _VendorEditPlaceholderPage({this.vendorId, this.initialData});

  @override
  Widget build(BuildContext context) {
    final isEdit = vendorId != null && vendorId!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '編輯廠商' : '新增廠商')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build_circle_outlined, size: 44),
                  const SizedBox(height: 10),
                  Text(
                    isEdit ? '廠商編輯頁尚未接入（占位）' : '廠商新增頁尚未接入（占位）',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEdit ? 'vendorId：${vendorId!}' : '目前是新增模式（vendorId 未提供）',
                    textAlign: TextAlign.center,
                  ),
                  if (initialData != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'initialData keys：${initialData!.keys.length}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, '/admin_vendors'),
                        icon: const Icon(Icons.store_mall_directory_outlined),
                        label: const Text('回廠商列表'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.pushReplacementNamed(
                            context, '/dashboard'),
                        icon: const Icon(Icons.dashboard_outlined),
                        label: const Text('回儀表板'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// Error Pages
// =======================================================

class FirebaseInitErrorApp extends StatelessWidget {
  final String error;
  const FirebaseInitErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Firebase 初始化失敗')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingArgPage extends StatelessWidget {
  final String title;
  final String message;
  const _MissingArgPage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _UnknownRoutePage extends StatelessWidget {
  final String routeName;
  const _UnknownRoutePage({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('找不到頁面')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 10),
                Text(
                  'Unknown route: $routeName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      icon: const Icon(Icons.login),
                      label: const Text('回登入'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/dashboard'),
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('回儀表板'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
