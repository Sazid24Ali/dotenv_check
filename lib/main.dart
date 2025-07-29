// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Removed unused import: import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:dotenv_check/screens/syllabus_image_picker.dart'; // Ensure correct path

Future<void> main() async {
  // Ensure Flutter binding is initialized before using plugins like dotenv
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file with your API key
  try {
    await dotenv.load(fileName: ".env");
    print("Environment variables loaded successfully.");
  } catch (e) {
    print("Error loading .env file: $e");
    // TODO: Consider showing a user-friendly error or exiting if critical
    // For example, an AlertDialog prompting the user to set up their API key
  }

  // NOTE: Closing TextRecognizer here is unusual as it should be managed
  // by the widget that uses it. Keeping for now as per your original code,
  // but typically you'd close it in the dispose method of the stateful widget.
  // TextRecognizer(script: TextRecognitionScript.latin).close(); // Correctly remains commented out

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syllabus AI Analyzer', // Updated title
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3:
            true, // Use Material 3 design system if your Flutter SDK supports it
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SyllabusImagePicker(), // Your main screen
      debugShowCheckedModeBanner: false,
    );
  }
}
