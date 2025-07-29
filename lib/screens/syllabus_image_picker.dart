// lib/screens/syllabus_image_picker.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../gemini/gemini_service.dart';
import '../models/syllabus_analyzer_models.dart';
import 'topic_editor_screen.dart';
// Removed unused import: import '../utils/syllabus_calculator.dart'; // No direct use here beyond passing data

class SyllabusImagePicker extends StatefulWidget {
  const SyllabusImagePicker({super.key});

  @override
  _SyllabusImagePickerState createState() => _SyllabusImagePickerState();
}

class _SyllabusImagePickerState extends State<SyllabusImagePicker> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String _extractedText = '';
  String _statusMessage = 'Pick an image of a syllabus to analyze.';
  bool _isLoading = false;

  List<Map<String, dynamic>> _recentParsedDataRaw = [];

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
  }

  Future<void> _loadRecentScans() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading past scans...';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? recentScansJson = prefs.getString('recent_syllabus_scans');
      if (recentScansJson != null) {
        final List<dynamic> decodedList = json.decode(recentScansJson);
        setState(() {
          _recentParsedDataRaw = decodedList
              .map((item) => item as Map<String, dynamic>)
              .toList();
          _statusMessage =
              'Loaded ${_recentParsedDataRaw.length} previous scans.';
        });
      } else {
        setState(() {
          _statusMessage = 'No previous scans found.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading recent scans: $e';
      });
      print('Error loading recent scans: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRecentScan(
    String title,
    SyllabusAnalysisResponse parsedSyllabus,
    String? imagePath,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> parsedJsonMap = parsedSyllabus.toJson();

    _recentParsedDataRaw.insert(0, {
      'title': title,
      'parsedJson': parsedJsonMap,
      'timestamp': DateTime.now().toIso8601String(),
      'imagePath': imagePath,
    });
    if (_recentParsedDataRaw.length > 10) {
      _recentParsedDataRaw = _recentParsedDataRaw.sublist(0, 10);
    }
    await prefs.setString(
      'recent_syllabus_scans',
      json.encode(_recentParsedDataRaw),
    );
    setState(() {}); // Refresh UI to show the new scan
  }

  void _handleSyllabusUpdate(SyllabusAnalysisResponse updatedSyllabus) {
    setState(() {
      // Find the existing entry and update it, or add if it's new (unlikely for update callback)
      final index = _recentParsedDataRaw.indexWhere((scan) {
        final existingSyllabus = SyllabusAnalysisResponse.fromJson(
          scan['parsedJson'],
        );
        // Using courseTitle and courseCode for a more robust identifier
        return existingSyllabus.courseTitle == updatedSyllabus.courseTitle &&
            existingSyllabus.courseCode == updatedSyllabus.courseCode;
      });

      if (index != -1) {
        _recentParsedDataRaw[index]['parsedJson'] = updatedSyllabus.toJson();
        _recentParsedDataRaw[index]['title'] =
            updatedSyllabus.courseTitle.isNotEmpty
            ? '${updatedSyllabus.courseTitle} Syllabus'
            : 'Edited Syllabus';
        _recentParsedDataRaw[index]['timestamp'] = DateTime.now()
            .toIso8601String(); // Update timestamp on edit
      } else {
        // This case should ideally not happen for an 'update' callback, but as a fallback:
        _recentParsedDataRaw.insert(0, {
          'title': updatedSyllabus.courseTitle.isNotEmpty
              ? '${updatedSyllabus.courseTitle} Syllabus'
              : 'Edited Syllabus',
          'parsedJson': updatedSyllabus.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
          // imagePath might not be available here, so handle gracefully if missing in the original entry
        });
        if (_recentParsedDataRaw.length > 10) {
          // Keep list size limited
          _recentParsedDataRaw = _recentParsedDataRaw.sublist(0, 10);
        }
      }
      _saveRecentScanList(); // Save the updated list to SharedPreferences
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _extractedText = '';
      _selectedImage = null;
      _statusMessage = 'Picking image...';
    });
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _statusMessage = 'Image picked. Performing OCR...';
        });
        await _performTextRecognition(_selectedImage!);
      } else {
        setState(() {
          _statusMessage = 'Image picking cancelled.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error picking image: $e';
        _isLoading = false;
        _selectedImage = null;
        _extractedText = '';
      });
      print('Error picking image: $e');
    }
  }

  Future<void> _performTextRecognition(File imageFile) async {
    setState(() {
      _statusMessage = 'Recognizing text...';
    });
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      setState(() {
        _extractedText = recognizedText.text.trim();
        print(
          'DEBUG: OCR Extracted Text:\n$_extractedText',
        ); // Added debug print for OCR text
      });

      if (_extractedText.isEmpty || _extractedText.length < 50) {
        setState(() {
          _statusMessage =
              'No significant text recognized. Please try a clearer image.';
          _isLoading = false;
          _selectedImage = null;
          _extractedText = '';
        });
        _showOcrWarningDialog();
        return;
      }

      setState(() {
        _statusMessage = 'Text recognized. Analyzing syllabus with AI...';
      });

      await _analyzeSyllabusWithGemini(_extractedText, imageFile.path);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error recognizing text: $e';
        _isLoading = false;
        _selectedImage = null;
        _extractedText = '';
      });
      print('Error recognizing text: $e');
    } finally {
      textRecognizer.close();
    }
  }

  void _showOcrWarningDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('OCR Failed or Insufficient Text'),
          content: const Text(
            'We could not extract enough meaningful text from the image. '
            'Please ensure the syllabus is well-lit, clearly focused, and fills the frame. '
            'Try taking another photo or picking a different image.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _analyzeSyllabusWithGemini(
    String ocrText,
    String? imagePath,
  ) async {
    setState(() {
      _statusMessage = 'Sending text to Gemini for structured analysis...';
    });
    try {
      final SyllabusAnalysisResponse? analysisResult =
          await GeminiService.analyzeSyllabus(ocrText);

      if (analysisResult != null) {
        // Debug print to check if syllabus is populated
        print('DEBUG: isSyllabus from Gemini: ${analysisResult.isSyllabus}');
        print(
          'DEBUG: Number of units from Gemini: ${analysisResult.units.length}',
        );
        if (analysisResult.units.isNotEmpty) {
          print('DEBUG: First unit name: ${analysisResult.units[0].unitName}');
          if (analysisResult.units[0].topics.isNotEmpty) {
            print(
              'DEBUG: First topic in first unit: ${analysisResult.units[0].topics[0].topic}',
            );
            print(
              'DEBUG: Estimated time for first topic: ${analysisResult.units[0].topics[0].estimatedTime}',
            );
          }
        }

        setState(() {
          _statusMessage = 'Syllabus successfully analyzed!';
          _selectedImage = null;
          _extractedText = '';
        });

        String scanTitle =
            analysisResult
                .courseTitle
                .isNotEmpty // Use .isNotEmpty on String, not null check
            ? '${analysisResult.courseTitle} Syllabus'
            : 'Syllabus Scan ${DateTime.now().toIso8601String().substring(0, 10)}';

        // Allow user to edit scan title before saving
        await _editScanTitle(null, initialTitle: scanTitle).then((value) {
          if (value != null && value.isNotEmpty) {
            scanTitle = value;
          }
        });

        await _saveRecentScan(scanTitle, analysisResult, imagePath);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopicEditorScreen(
              parsedSyllabus: analysisResult,
              scanTitle: scanTitle,
              onSyllabusUpdated: _handleSyllabusUpdate,
            ),
          ),
        );
      } else {
        setState(() {
          _statusMessage = 'Gemini analysis returned no data.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            'Failed to analyze syllabus with Gemini: ${e.toString()}';
        _selectedImage = null;
        _extractedText = '';
      });
      print('Gemini analysis error: $e');
      _showErrorDialog(
        'Gemini API Error',
        'Failed to get a valid response from Gemini. Please check your API key, network connection, or try a different syllabus image. Error: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _editScanTitle(int? index, {String? initialTitle}) async {
    final TextEditingController titleController = TextEditingController(
      text:
          initialTitle ??
          (index != null ? _recentParsedDataRaw[index]['title'] : ''),
    );
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Scan Title'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              hintText: 'e.g., "Math 101 Syllabus"',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  if (index != null) {
                    setState(() {
                      _recentParsedDataRaw[index]['title'] =
                          titleController.text;
                      _saveRecentScanList();
                    });
                  }
                  Navigator.of(context).pop(titleController.text);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRecentScanList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'recent_syllabus_scans',
      json.encode(_recentParsedDataRaw),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Scan'),
          content: Text(
            'Are you sure you want to delete "${_recentParsedDataRaw[index]['title']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _recentParsedDataRaw.removeAt(index);
                  _saveRecentScanList();
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openExistingScan(Map<String, dynamic> scanData) {
    final SyllabusAnalysisResponse parsedSyllabus =
        SyllabusAnalysisResponse.fromJson(scanData['parsedJson']);
    // No longer nullable as defaultValue ensures it's always a valid object

    if (parsedSyllabus.units.isNotEmpty) {
      // Check if units are populated
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TopicEditorScreen(
            parsedSyllabus: parsedSyllabus,
            scanTitle: scanData['title'] ?? 'Untitled Scan',
            onSyllabusUpdated: _handleSyllabusUpdate,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Could not load syllabus data or it is empty.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllabus Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecentScans,
            tooltip: 'Refresh Recent Scans',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'For best results, ensure the syllabus is well-lit, clearly focused, '
                'and fills most of the camera frame.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo of Syllabus'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.image),
              label: const Text('Pick from Gallery'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color:
                      _statusMessage.contains('Error') ||
                          _statusMessage.contains('No significant text')
                      ? Colors.red
                      : Colors.blueGrey,
                ),
              ),
            ),
            // OCR Preview - Wrapped in Expanded
            if (_extractedText.isNotEmpty && !_isLoading)
              Expanded(
                flex: 1,
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 10.0),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'OCR Preview:\n$_extractedText',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            // Image Preview - Wrapped in Expanded
            if (_selectedImage != null)
              Expanded(
                flex: 1,
                child: Container(
                  height: 150,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Recent Scans:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Recent Scans List - Wrapped in Expanded
            Expanded(
              flex: 3,
              child: _recentParsedDataRaw.isEmpty
                  ? Center(
                      child: Text(
                        _isLoading ? 'Loading...' : 'No recent scans.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _recentParsedDataRaw.length,
                      itemBuilder: (context, index) {
                        final item = _recentParsedDataRaw[index];
                        Widget leadingWidget;
                        try {
                          final String? imagePath = item['imagePath'];
                          if (imagePath != null &&
                              File(imagePath).existsSync()) {
                            leadingWidget = CircleAvatar(
                              backgroundImage: FileImage(File(imagePath)),
                            );
                          } else {
                            leadingWidget = const CircleAvatar(
                              child: Icon(Icons.description),
                            );
                          }
                        } catch (e) {
                          print("Error loading thumbnail: $e");
                          leadingWidget = const CircleAvatar(
                            child: Icon(Icons.description),
                          );
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            leading: leadingWidget,
                            title: Text(
                              item['title'] ?? "Syllabus ${index + 1}",
                            ),
                            subtitle: Text(
                              'Scanned: ${item['timestamp'] != null ? DateTime.parse(item['timestamp']).toLocal().toString().substring(0, 16) : 'N/A'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editScanTitle(index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmDelete(index),
                                ),
                              ],
                            ),
                            onTap: () => _openExistingScan(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
