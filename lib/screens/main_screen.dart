// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'syllabus_image_picker.dart'; // Import the syllabus scanning screen
import 'saved_plans_list_screen.dart'; // We will create this screen next

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllabus AI Analyzer'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 250, // Fixed width for buttons
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SyllabusImagePicker(),
                    ),
                  );
                },
                icon: const Icon(Icons.document_scanner, size: 30),
                label: const Text(
                  'Scan New Syllabus',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250, // Fixed width for buttons
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedPlansListScreen(),
                    ), // Navigate to plans list
                  );
                },
                icon: const Icon(Icons.list_alt, size: 30),
                label: const Text(
                  'My Study Plans',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
