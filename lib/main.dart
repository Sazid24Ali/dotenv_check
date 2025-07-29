// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart'
    as _tz_data; // Aliased for initializeAll()
import 'package:timezone/timezone.dart'
    as tz; // Aliased for TZDateTime and local
import 'package:dotenv_check/screens/main_screen.dart'; // Import MainScreen

// THIS GLOBAL DECLARATION IS CRUCIAL. It must be at the top level, outside any class.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  // Ensure Flutter binding is initialized before using plugins like dotenv
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file
  try {
    await dotenv.load(fileName: ".env");
    print("Environment variables loaded successfully.");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  // Initialize local notifications (COMMENTED OUT AS PER YOUR REQUEST FOR NOW)
  // _tz_data.initializeTimeZones(); // Use initializeTimeZones() for your specific version
  // tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Set local timezone

  // Configure notification settings for Android and iOS (COMMENTED OUT AS PER YOUR REQUEST FOR NOW)
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin = 
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  // await flutterLocalNotificationsPlugin.initialize(
  //   initializationSettings,
  //   onDidReceiveNotificationResponse: (NotificationResponse response) async {
  //     if (response.payload != null) {
  //       debugPrint('Notification tapped (foreground), payload: ${response.payload}');
  //     }
  //   },
  //   onDidReceiveBackgroundNotificationResponse: (NotificationResponse response) {
  //     if (response.payload != null) {
  //       debugPrint('Notification tapped (background/terminated), payload: ${response.payload}');
  //     }
  //   },
  // );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syllabus AI Analyzer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}