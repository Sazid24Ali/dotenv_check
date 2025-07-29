// lib/screens/topic_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Removed unused import: import 'dart:convert';
import '../models/syllabus_analyzer_models.dart';
import '../utils/syllabus_calculator.dart'; // Import the calculator utility
import 'study_plan_input_screen.dart'; // NEW: Import for navigation

class TopicEditorScreen extends StatefulWidget {
  final SyllabusAnalysisResponse parsedSyllabus;
  final String scanTitle;
  // Callback to update the parent list (SyllabusImagePicker's recent scans)
  final Function(SyllabusAnalysisResponse updatedSyllabus)? onSyllabusUpdated;

  const TopicEditorScreen({
    super.key,
    required this.parsedSyllabus,
    this.scanTitle = 'Analyzed Syllabus',
    this.onSyllabusUpdated, // Accept the callback
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
    _currentSyllabus = widget.parsedSyllabus; // Initialize with passed data
    // Calculate initial totals using the external utility (safe if done in service, but good safeguard)
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

  // This method now triggers the callback to update the parent list
  void _saveChanges() {
    // Recalculate all totals one last time before saving via callback
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
    setState(() {}); // Refresh UI after saving (e.g., if totals changed)
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
          node.unitName = newName; // Direct mutation
        } else if (node is Topic) {
          node.topic = newName; // Direct mutation
        }
        // Recalculate totals after name change (just in case derived values exist)
        SyllabusCalculator.calculateAllTotals(_currentSyllabus);
      });
      _saveChanges(); // Save changes immediately after edit
    }
  }

  void _editEstimatedTime(Topic topic) async {
    int currentEstimatedTime = topic.estimatedTime;
    final newTime = await showDialog<int>(
      // Dialog will return an int
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Estimated Time (minutes)'),
          content: StatefulBuilder(
            // Use StatefulBuilder for internal state changes
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentEstimatedTime} minutes',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle),
                        onPressed: () {
                          setState(() {
                            if (currentEstimatedTime > 0)
                              currentEstimatedTime -= 5; // Decrement by 5 mins
                          });
                        },
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller:
                              TextEditingController(
                                  text: currentEstimatedTime.toString(),
                                )
                                ..selection = TextSelection.fromPosition(
                                  TextPosition(
                                    offset: currentEstimatedTime
                                        .toString()
                                        .length,
                                  ),
                                ), // Keep cursor at end
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            setState(() {
                              currentEstimatedTime =
                                  int.tryParse(value) ??
                                  0; // Default to 0 if invalid
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
                            currentEstimatedTime += 5; // Increment by 5 mins
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Set in: ${formatTime(currentEstimatedTime)}',
                  ), // Show formatted time
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
              onPressed: () => Navigator.pop(
                context,
                currentEstimatedTime,
              ), // Return the integer
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
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
            tooltip: 'Save current changes',
          ),
        ],
      ),
      body:
          _currentSyllabus
              .units
              .isEmpty // Check if units list is empty
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
              .map((topic) => _buildTopicEditor(topic, unit.topics, 0))
              .toList(),
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
              if (topic.timeReasoning.isNotEmpty) // Use .isNotEmpty for String
                Text(
                  'Reasoning: ${topic.timeReasoning}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              if (topic.resources.isNotEmpty) // Use .isNotEmpty for List
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
            // Render subtopics recursively
            ...topic.subtopics
                .map(
                  (subtopic) =>
                      _buildTopicEditor(subtopic, topic.subtopics, level + 1),
                )
                .toList(),
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
