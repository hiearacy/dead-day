import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dead_day/app/game_controller.dart';
import 'package:dead_day/ui/game_screen.dart';

void main() {
  testWidgets('game screen shows a loading state before initialization',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final controller = GameController();
    await tester.pumpWidget(MaterialApp(home: GameScreen(controller: controller)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.dispose();
  });
}
