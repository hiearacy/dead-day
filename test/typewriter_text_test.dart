import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dead_day/ui/typewriter_text.dart';

void main() {
  testWidgets('reduced motion shows the complete story immediately',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: TypewriterText(text: '서울역 B3 구역에 도착했다.')),
      ),
    ));
    expect(find.text('서울역 B3 구역에 도착했다.'), findsOneWidget);
  });

  testWidgets('typewriter can replace its story text',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TypewriterText(text: '첫 번째 장면')),
    ));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TypewriterText(text: '두 번째 장면')),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('두 번째 장면'), findsOneWidget);
  });
}
