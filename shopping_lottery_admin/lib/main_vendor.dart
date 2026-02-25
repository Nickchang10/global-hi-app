// lib/main_vendor.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'gates/vendor_gate.dart';
import 'pages/vendor/vendor_shell_page.dart';
import 'pages/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VendorAppRoot());
}

class VendorAppRoot extends StatelessWidget {
  const VendorAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<VendorGate>(
          create: (_) {
            final gate = VendorGate();
            gate.bindAuth();
            return gate;
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Osmile Vendor',
        theme: ThemeData(useMaterial3: true),
        initialRoute: '/vendor',
        routes: {
          '/vendor': (_) => const VendorShellPage(),
          '/login': (_) => const LoginPage(),
        },
      ),
    );
  }
}
