import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ RoleInfo（提供給 UI / Badge 使用）
/// - 你先前有檔案在用 roleInfo.error，因此這裡補上 error 欄位
@immutable
class RoleInfo {
  const RoleInfo({
    required this.uid,
    required this.role,
    required this.loading,
    this.error,
  });

  final String? uid;
  final String role; // 'user' / 'vendor' / 'admin' / 'super_admin'
  final bool loading;
  final String? error;

  bool get isLoggedIn => uid != null && uid!.isNotEmpty;
  bool get isUser => role == 'user';
  bool get isVendor => role == 'vendor';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  RoleInfo copyWith({String? uid, String? role, bool? loading, String? error}) {
    return RoleInfo(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  static RoleInfo loadingState({String? uid}) =>
      RoleInfo(uid: uid, role: 'user', loading: true);

  static RoleInfo guest({String? error}) =>
      RoleInfo(uid: null, role: 'user', loading: false, error: error);
}

/// ✅ RoleGate（角色閘道）
/// ------------------------------------------------------------
/// 修正重點：
/// - ❌ 不再 import ../pages/admin_shell_page.dart（因為檔案不存在）
/// - ✅ 改成由外部傳入 adminPage/vendorPage/userPage
/// - ✅ 或用 routeName 導頁（不依賴檔案存在）
/// ------------------------------------------------------------
class RoleGate extends StatefulWidget {
  const RoleGate({
    super.key,
    required this.userPage,
    this.adminPage,
    this.vendorPage,
    this.loginPage,
    this.loadingWidget,
    this.errorBuilder,

    /// 若你想用路由導頁（pushReplacementNamed），設為 true
    this.redirectByRoute = false,
    this.adminRouteName = '/admin',
    this.vendorRouteName = '/vendor',
    this.userRouteName = '/',

    /// Firestore 設定
    this.userCollection = 'users',
    this.roleField = 'role',
    this.defaultRole = 'user',
  });

  final Widget userPage;
  final Widget? adminPage;
  final Widget? vendorPage;
  final Widget? loginPage;
  final Widget? loadingWidget;

  final Widget Function(BuildContext context, RoleInfo info)? errorBuilder;

  final bool redirectByRoute;
  final String adminRouteName;
  final String vendorRouteName;
  final String userRouteName;

  final String userCollection;
  final String roleField;
  final String defaultRole;

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  RoleInfo _info = RoleInfo.loadingState();

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    setState(
      () => _info = RoleInfo.loadingState(
        uid: FirebaseAuth.instance.currentUser?.uid,
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _info = RoleInfo.guest(error: 'not_logged_in'));
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection(widget.userCollection)
          .doc(user.uid)
          .get();

      final data = doc.data() ?? const <String, dynamic>{};
      final roleRaw = (data[widget.roleField] ?? widget.defaultRole)
          .toString()
          .trim()
          .toLowerCase();

      final role = roleRaw.isEmpty ? widget.defaultRole : roleRaw;

      setState(() {
        _info = RoleInfo(
          uid: user.uid,
          role: role,
          loading: false,
          error: null,
        );
      });

      if (widget.redirectByRoute && mounted) {
        _redirectIfNeeded(_info);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _info = RoleInfo(
          uid: FirebaseAuth.instance.currentUser?.uid,
          role: widget.defaultRole,
          loading: false,
          error: e.toString(),
        );
      });
    }
  }

  void _redirectIfNeeded(RoleInfo info) {
    // 避免 build 期間直接 push 造成循環
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!info.isLoggedIn) {
        // 沒登入就不導頁（或你可自行在 loginPage 做導頁）
        return;
      }

      final target = info.isAdmin
          ? widget.adminRouteName
          : info.isVendor
          ? widget.vendorRouteName
          : widget.userRouteName;

      // pushReplacementNamed（不依賴 import 某個頁面）
      Navigator.of(context).pushReplacementNamed(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_info.loading) {
      return widget.loadingWidget ??
          const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 有錯誤時（例如 Firestore 欄位/權限問題），可自訂顯示
    if (_info.error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _info);
    }

    // 未登入
    if (!_info.isLoggedIn) {
      return widget.loginPage ??
          Scaffold(
            appBar: AppBar(title: const Text('需要登入')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('請先登入後再使用', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    child: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          );
    }

    // 如果採用 route 導頁，就給一個過場（避免畫面閃）
    if (widget.redirectByRoute) {
      return widget.loadingWidget ??
          const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 直接回傳對應頁面（不需要任何 import）
    if (_info.isAdmin) {
      return widget.adminPage ?? const _MissingAdminShellPage();
    }
    if (_info.isVendor) {
      return widget.vendorPage ?? const _MissingVendorShellPage();
    }
    return widget.userPage;
  }
}

class _MissingAdminShellPage extends StatelessWidget {
  const _MissingAdminShellPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '找不到 AdminShellPage。\n\n'
            '你目前的 RoleGate 已不再 import ../pages/admin_shell_page.dart 以避免編譯失敗。\n'
            '請在 RoleGate 傳入 adminPage，或改用 redirectByRoute=true 導到 /admin。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _MissingVendorShellPage extends StatelessWidget {
  const _MissingVendorShellPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '找不到 VendorShellPage。\n\n'
            '請在 RoleGate 傳入 vendorPage，或改用 redirectByRoute=true 導到 /vendor。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
