// lib/main.dart
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dotenv_check/screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env file: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syllabus AI Analyzer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A148C),
          primary: const Color(0xFF6A1B9A),
          secondary: const Color(0xFFEC407A),
          background: const Color(0xFFF3E5F5),
        ),
        useMaterial3: true,
        // --- FIX: Reverted to a solid color theme for safety ---
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          // This color will be covered by our custom gradient app bar
          backgroundColor: Color(0xFF8E24AA),
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
