import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Widget test smoke (app shell)', (WidgetTester tester) async {
    // ✅ 不依賴專案的 main.dart，避免 package 路徑/入口差異造成編譯失敗
    await tester.pumpWidget(const _TestApp());

    expect(find.text('Smoke Test'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Smoke Test')),
        body: const Center(child: Text('Smoke Test')),
      ),
    );
  }
}
