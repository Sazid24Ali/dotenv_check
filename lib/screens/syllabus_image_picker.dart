import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../gemini/gemini_service.dart';
import 'topic_editor_screen.dart';

class SyllabusImagePicker extends StatefulWidget {
  @override
  _SyllabusImagePickerState createState() => _SyllabusImagePickerState();
}

String cleanJson(String rawResponse) {
  final cleaned = rawResponse.trim();
  if (cleaned.startsWith('```json')) {
    return cleaned.replaceAll(RegExp(r'^```json|```$'), '').trim();
  }
  return cleaned;
}

class _SyllabusImagePickerState extends State<SyllabusImagePicker> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String _extractedText = '';
  List<Map<String, dynamic>> recentParsedData = [];

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
          print("OCR SUCCESS");
          final result = await GeminiService.parseSyllabusWithGemini(
            _extractedText,
          );
          final cleaned = cleanJson(result);
          final parsedJson = jsonDecode(cleaned);

          // Add to recent
          setState(() {
            recentParsedData.insert(0, {
              'imagePath': imageFile.path,
              'parsedJson': parsedJson,
            });
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TopicEditorScreen(parsedJson: parsedJson),
            ),
          ).then((_) {
            setState(() {
              _selectedImage = null;
            });
          });
        } else {
          _showError("No readable text found. Try a clearer image.");
        }
      } catch (e) {
        _showError("OCR/Gemini failed: $e");
      }
    }
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

            if (recentParsedData.isNotEmpty) ...[
              Divider(),
              Text(
                "📸 Recent Scans",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
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
                      title: Text("Syllabus ${index + 1}"),
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
