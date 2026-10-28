import 'package:flutter/material.dart';
import 'app/game_controller.dart';
import 'ui/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeadDayApp());
}

class DeadDayApp extends StatefulWidget {
  const DeadDayApp({super.key});

  @override
  State<DeadDayApp> createState() => _DeadDayAppState();
}

class _DeadDayAppState extends State<DeadDayApp> {
  final GameController _controller = GameController();

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DEAD DAY',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF93C5B5),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF101719),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A2527),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    home: GameScreen(controller: _controller),
  );
}
