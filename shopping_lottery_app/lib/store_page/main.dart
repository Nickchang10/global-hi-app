import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const ShopApp(),
    ),
  );
}

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // standalone store app no longer uses custom router
    return MaterialApp(
      title: '商店',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6), // gray-100
      ),
      home: const Scaffold(
        body: Center(child: Text('Store entry (router removed)')),
      ),
    );
  }
}
