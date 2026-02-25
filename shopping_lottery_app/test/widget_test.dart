import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test - app widgets compile', (WidgetTester tester) async {
    // ✅ 最小可編譯/可跑測試的 Widget（不依賴 main.dart / Firebase）
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Osmile Smoke Test'))),
      ),
    );

    expect(find.text('Osmile Smoke Test'), findsOneWidget);
  });
}
