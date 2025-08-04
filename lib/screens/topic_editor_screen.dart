// lib/screens/topic_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/syllabus_analyzer_models.dart';
import '../utils/syllabus_calculator.dart';
import '../utils/pdf_generator.dart';
import 'study_plan_input_screen.dart'; // FIX: Ensure this import is present and correct
import 'pdf_viewer_screen.dart'; // Import the PDF viewer screen

class TopicEditorScreen extends StatefulWidget {
  final SyllabusAnalysisResponse parsedSyllabus;
  final String scanTitle;
  final Function(SyllabusAnalysisResponse updatedSyllabus)? onSyllabusUpdated;

  const TopicEditorScreen({
    super.key,
    required this.parsedSyllabus,
    this.scanTitle = 'Analyzed Syllabus',
    this.onSyllabusUpdated,
  });

  @override
  State<TopicEditorScreen> createState() => _TopicEditorScreenState();
}

class _TopicEditorScreenState extends State<TopicEditorScreen> {
  late SyllabusAnalysisResponse _currentSyllabus;
  bool showInHours = false;

  @override
  void initState() {
    super.initState();
    _currentSyllabus = widget.parsedSyllabus;
    SyllabusCalculator.calculateAllTotals(_currentSyllabus);
    _loadShowInHoursSetting();
  }

  Future<void> _loadShowInHoursSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showInHours = prefs.getBool('showInHours') ?? false;
    });
  }

  Future<void> _saveShowInHoursSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showInHours', value);
  }

  void _saveChanges() {
    SyllabusCalculator.calculateAllTotals(_currentSyllabus);
    if (widget.onSyllabusUpdated != null) {
      widget.onSyllabusUpdated!(_currentSyllabus);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!')),
      );
    } else {
      print(
        "Warning: onSyllabusUpdated callback is null. Changes might not persist.",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save changes persistently.')),
      );
    }
    setState(() {});
  }

  String formatTime(int minutes) {
    if (minutes < 0) return "N/A";
    if (!showInHours) return "$minutes mins";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return "${h}h ${m}m";
    if (h > 0) return "${h}h";
    return "${m}m";
  }

  Future<void> _generateAndDownloadPdf() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating PDF...'),
        duration: Duration(seconds: 2),
      ),
    );

    final String pdfFilePath = await PdfGenerator.generateSyllabusPdf(
      _currentSyllabus,
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PdfViewerScreen(pdfPath: pdfFilePath, title: widget.scanTitle),
      ),
    );
    // try {
    //   var status = await Permission.storage.status;
    //   if (!status.isGranted) {
    //     status = await Permission.storage.request();
    //   }

    //   if (status.isGranted) {
    //     final String pdfFilePath = await PdfGenerator.generateSyllabusPdf(
    //       _currentSyllabus,
    //     );
    //     ScaffoldMessenger.of(context).hideCurrentSnackBar();

    //     Navigator.push(
    //       context,
    //       MaterialPageRoute(
    //         builder: (context) =>
    //             PdfViewerScreen(pdfPath: pdfFilePath, title: widget.scanTitle),
    //       ),
    //     );
    //   } else {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text(
    //           'Storage permission denied. Cannot save PDF. Please enable it in app settings.',
    //         ),
    //         duration: Duration(seconds: 5),
    //       ),
    //     );
    //     if (status.isDenied) {
    //       await openAppSettings();
    //     }
    //   }
    // } catch (e, stacktrace) {
    //   print('Error generating PDF: $e');
    //   print('Stacktrace: $stacktrace');
    //   ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Failed to generate PDF: ${e.toString()}')),
    //   );
    // }
  }

  void _editName(dynamic node, String label) async {
    final controller = TextEditingController(
      text: node is Unit ? node.unitName : node.topic,
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $label Name'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new $label name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        if (node is Unit) {
          node.unitName = newName;
        } else if (node is Topic) {
          node.topic = newName;
        }
        SyllabusCalculator.calculateAllTotals(_currentSyllabus);
      });
      _saveChanges();
    }
  }

  void _editEstimatedTime(Topic topic) async {
    int currentEstimatedTime = topic.estimatedTime;
    final newTime = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Estimated Time (minutes)'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$currentEstimatedTime minutes',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle),
                        onPressed: () {
                          setState(() {
                            if (currentEstimatedTime > 0) {
                              currentEstimatedTime -= 5;
                            }
                          });
                        },
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: TextEditingController(
                            text: currentEstimatedTime.toString(),
                          )..selection = TextSelection.fromPosition(
                              TextPosition(
                                offset: currentEstimatedTime.toString().length,
                              ),
                            ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            setState(() {
                              currentEstimatedTime = int.tryParse(value) ?? 0;
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(8),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () {
                          setState(() {
                            currentEstimatedTime += 5;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Set in: ${formatTime(currentEstimatedTime)}'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, currentEstimatedTime),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newTime != null && newTime >= 0) {
      setState(() {
        topic.estimatedTime = newTime;
        SyllabusCalculator.calculateAllTotals(_currentSyllabus);
      });
      _saveChanges();
    }
  }

  void _editImportanceDifficulty(Topic topic, String type) async {
    double currentValue = type == 'importance'
        ? topic.importance.toDouble()
        : topic.difficulty.toDouble();
    double sliderValue = currentValue;

    final newSliderValue = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Edit ${type == 'importance' ? 'Importance' : 'Difficulty'} (1-5)',
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: sliderValue,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: sliderValue.round().toString(),
                    onChanged: (newValue) {
                      setState(() {
                        sliderValue = newValue;
                      });
                    },
                  ),
                  Text('Current: ${sliderValue.round()}'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, sliderValue),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newSliderValue != null) {
      final int intValue = newSliderValue.round();
      setState(() {
        if (type == 'importance') {
          topic.importance = intValue;
        } else {
          topic.difficulty = intValue;
        }
        SyllabusCalculator.calculateAllTotals(_currentSyllabus);
      });
      _saveChanges();
    }
  }

  void _deleteNode<T>(List<T> list, T nodeToDelete) {
    setState(() {
      list.remove(nodeToDelete);
      SyllabusCalculator.calculateAllTotals(_currentSyllabus);
    });
    _saveChanges();
  }

  void _addTopic(List<Topic> parentTopics) {
    setState(() {
      parentTopics.add(
        Topic(
          topic: 'New Topic',
          estimatedTime: 15,
          importance: 3,
          difficulty: 3,
          resources: [],
          subtopics: [],
          timeReasoning: 'Manually added by user',
        ),
      );
      SyllabusCalculator.calculateAllTotals(_currentSyllabus);
    });
    _saveChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scanTitle),
        actions: [
          IconButton(
            icon: Icon(showInHours ? Icons.watch_later : Icons.timer),
            onPressed: () {
              setState(() {
                showInHours = !showInHours;
              });
              _saveShowInHoursSetting(showInHours);
            },
            tooltip: 'Toggle time display (mins/hours)',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateAndDownloadPdf,
            tooltip: 'View Syllabus PDF',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
            tooltip: 'Save current changes',
          ),
        ],
      ),
      body: _currentSyllabus.units.isEmpty
          ? const Center(
              child: Text(
                'No syllabus units found. Try re-analyzing or adding manually.',
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _currentSyllabus.units.length,
                    itemBuilder: (context, index) {
                      final unit = _currentSyllabus.units[index];
                      return _buildUnitEditor(unit);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              // FIX: Explicitly instantiate StudyPlanInputScreen as a Widget
                              StudyPlanInputScreen(syllabus: _currentSyllabus),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Generate Study Plan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUnitEditor(Unit unit) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2,
      child: ExpansionTile(
        key: PageStorageKey(unit.unitName),
        title: Row(
          children: [
            Expanded(child: Text(unit.unitName)),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editName(unit, 'Unit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteNode(_currentSyllabus.units, unit),
            ),
          ],
        ),
        subtitle: Text("Total Time: ${formatTime(unit.totalEstimatedTime)}"),
        children: [
          ...unit.topics
              .map((topic) => _buildTopicEditor(topic, unit.topics, 0)),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add New Topic to Unit"),
              onPressed: () => _addTopic(unit.topics),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicEditor(Topic topic, List<Topic> parentTopics, int level) {
    final double indent = level * 16.0;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
        elevation: 1,
        child: ExpansionTile(
          key: PageStorageKey('${topic.topic}_$level'),
          title: Row(
            children: [
              Expanded(child: Text(topic.topic)),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editName(topic, 'Topic'),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteNode(parentTopics, topic),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time: ${formatTime(topic.estimatedTime)}'),
              Text(
                'Importance: ${topic.importance}, Difficulty: ${topic.difficulty}',
              ),
              if (topic.timeReasoning.isNotEmpty)
                Text(
                  'Reasoning: ${topic.timeReasoning}',
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                ),
              if (topic.resources.isNotEmpty)
                Text(
                  'Resources: ${topic.resources.join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () => _editEstimatedTime(topic),
                    child: const Text('Edit Time'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _editImportanceDifficulty(topic, 'importance'),
                    child: const Text('Edit Imp.'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _editImportanceDifficulty(topic, 'difficulty'),
                    child: const Text('Edit Diff.'),
                  ),
                ],
              ),
            ),
            ...topic.subtopics.map(
              (subtopic) =>
                  _buildTopicEditor(subtopic, topic.subtopics, level + 1),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text("Add Subtopic to ${topic.topic}"),
                onPressed: () => _addTopic(topic.subtopics),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
