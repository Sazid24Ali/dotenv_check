import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../gemini/gemini_service.dart';
import 'topic_editor_screen.dart';

class SyllabusImagePicker extends StatefulWidget {
  const SyllabusImagePicker({super.key});

  @override
  _SyllabusImagePickerState createState() => _SyllabusImagePickerState();
}

String cleanJson(String rawResponse) {
  final cleaned = rawResponse.trim();
  if (cleaned.startsWith('```json')) {
    return cleaned.replaceAll(RegExp(r'^```json|```'), '').trim();
  }
  return cleaned;
}

class _SyllabusImagePickerState extends State<SyllabusImagePicker> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String _extractedText = '';
  List<Map<String, dynamic>> recentParsedData = [];

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
    _loadSavedSyllabus();
  }

  Future<void> _loadSavedSyllabus() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('last_edited_syllabus');
    if (saved != null) {
      final parsed = jsonDecode(saved);
      setState(() {
        recentParsedData.insert(0, {
          'imagePath': '', // optional placeholder
          'parsedJson': parsed,
          'title': 'Last Edited',
        });
      });
    }
  }

  Future<void> _loadRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('recent_scans');
    if (storedData != null) {
      final List decodedList = jsonDecode(storedData);
      setState(() {
        recentParsedData = List<Map<String, dynamic>>.from(decodedList);
      });
    }
  }

  Future<void> _saveRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(recentParsedData);
    await prefs.setString('recent_scans', encoded);
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      setState(() {
        _selectedImage = imageFile;
        _extractedText = '';
      });

      try {
        final inputImage = InputImage.fromFile(imageFile);
        final textRecognizer = TextRecognizer(
          script: TextRecognitionScript.latin,
        );
        final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage,
        );
        await textRecognizer.close();

        if (recognizedText.text.trim().isNotEmpty) {
          _extractedText = recognizedText.text;

          // Show loading dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Expanded(child: Text("Analyzing syllabus...")),
                ],
              ),
            ),
          );

          Map<String, dynamic>? parsedJson;

          // print(_extractedText);
          try {
            final result = await GeminiService.parseSyllabusWithGemini(
              _extractedText,
            );

            final cleaned = cleanJson(result);

            if (cleaned.toLowerCase().contains('not_syllabus')) {
              Navigator.of(context).pop(); // Dismiss loader
              _showError(
                "This image doesn't appear to contain a valid syllabus.",
              );
              return;
            }
            parsedJson = jsonDecode(cleaned);

            Navigator.of(context).pop(); // Dismiss loader

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TopicEditorScreen(parsedJson: parsedJson!),
              ),
            ).then((_) {
              setState(() {
                _selectedImage = null;
              });
            });

            setState(() {
              recentParsedData.insert(0, {
                'imagePath': imageFile.path,
                'parsedJson': parsedJson,
                'title': "Syllabus ${recentParsedData.length + 1}",
              });
              _saveRecentScans(); // ✅ Save after update
            });
          } catch (e) {
            Navigator.of(context).pop();
            print("Gemini Error: $e");
            _showError("Error analyzing syllabus: $e");
          }
        } else {
          _showError("No readable text found. Try a clearer image.");
        }
      } catch (e) {
        _showError("OCR/Gemini failed: $e");
      }
    }
    setState(() {
      _selectedImage = null;
    });
  }

  void _editScanTitle(int index) async {
    final controller = TextEditingController(
      text: recentParsedData[index]['title'] ?? "Syllabus ${index + 1}",
    );

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Title"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new title"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      setState(() {
        recentParsedData[index]['title'] = newTitle;
        _saveRecentScans(); // ✅ Save
      });
    }
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Scan?"),
        content: const Text(
          "Are you sure you want to delete this recent scan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                recentParsedData.removeAt(index);
                _saveRecentScans(); // ✅ Save
              });
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Syllabus Scanner')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 200),
            ElevatedButton.icon(
              icon: Icon(Icons.photo),
              label: Text("Gallery"),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.camera),
              label: Text("Camera"),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            SizedBox(height: 24),
            Divider(),
            Text(
              "📸 Recent Scans",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (recentParsedData.isNotEmpty) ...[
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentParsedData.length,
                itemBuilder: (context, index) {
                  final item = recentParsedData[index];
                  return Card(
                    child: ListTile(
                      leading: Image.file(
                        File(item['imagePath']),
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(item['title'] ?? "Syllabus ${index + 1}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editScanTitle(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(index),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TopicEditorScreen(
                              parsedJson: item['parsedJson'],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
