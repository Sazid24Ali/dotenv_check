import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TopicEditorScreen extends StatefulWidget {
  final Map<String, dynamic> parsedJson;

  const TopicEditorScreen({super.key, required this.parsedJson});

  @override
  State<TopicEditorScreen> createState() => _TopicEditorScreenState();
}

class _TopicEditorScreenState extends State<TopicEditorScreen> {
  late List<dynamic> units;

  bool showInHours = false;
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_edited_syllabus',
      jsonEncode(widget.parsedJson),
    );
  }

  @override
  void initState() {
    super.initState();
    units = widget.parsedJson['units'];
  }

  String formatTime(int minutes) {
    if (!showInHours) return "$minutes mins";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return "${h}h ${m}m";
    if (h > 0) return "${h}h";
    return "${m}m";
  }

  void _editName(Map<String, dynamic> node, String label) async {
    final controller = TextEditingController(
      text: node['topic'] ?? node['unit_name'],
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit $label"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "Enter $label name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      setState(() {
        if (node.containsKey('unit_name')) {
          node['unit_name'] = newName.trim();
        } else {
          node['topic'] = newName.trim();
        }
      });
      _saveToPrefs();
    }
  }

  void _deleteNode(List<dynamic> list, Map<String, dynamic> node) {
    final subitems = node['subtopics'] ?? node['topics'] ?? [];

    if (subitems.length > 1) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Are you sure?"),
          content: const Text(
            "This has sub-topics . Do you still want to delete it?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => list.remove(node));
                Navigator.pop(context);
              },
              child: const Text("Delete"),
            ),
          ],
        ),
      );
    } else {
      setState(() => list.remove(node));
    }
    _saveToPrefs();
  }

  Widget buildTopicEditor(
    Map<String, dynamic> topic,
    List<dynamic> parentList,
  ) {
    final List<dynamic> subtopics = topic['subtopics'] ?? [];

    return ExpansionTile(
      key: ValueKey(topic),
      title: Row(
        children: [
          Expanded(child: Text(topic['topic'] ?? 'Unnamed Topic')),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editName(topic, "Topic"),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteNode(parentList, topic),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Text("Time: ${formatTime(topic['estimated_time'] ?? 15)}"),
                  Expanded(
                    child: Slider(
                      value: ((topic['estimated_time'] ?? 15) as num)
                          .toDouble()
                          .clamp(5, 240),
                      min: 5,
                      max: 240,
                      divisions: 47,
                      label: "${topic['estimated_time'] ?? 15} min",
                      onChanged: (val) {
                        setState(() => topic['estimated_time'] = val.round());
                        _saveToPrefs();
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text("Importance: ${topic['importance'] ?? 3}"),
                  Expanded(
                    child: Slider(
                      value: ((topic['importance'] ?? 3) as num)
                          .toDouble()
                          .clamp(1, 5),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: (val) {
                        setState(() => topic['importance'] = val.round());
                        _saveToPrefs();
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text("Difficulty: ${topic['difficulty'] ?? 2}"),
                  Expanded(
                    child: Slider(
                      value: ((topic['difficulty'] ?? 2) as num)
                          .toDouble()
                          .clamp(1, 5),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: (val) {
                        setState(() => topic['difficulty'] = val.round());
                        _saveToPrefs();
                      },
                    ),
                  ),
                ],
              ),
              if (subtopics.isNotEmpty)
                ...subtopics
                    .map((child) => buildTopicEditor(child, subtopics))
                    .toList(),

              if (subtopics.isEmpty) const SizedBox(height: 8),

              if (subtopics.isEmpty || true)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Subtopic"),
                    onPressed: () {
                      setState(() {
                        topic['subtopics'] = topic['subtopics'] ?? [];
                        topic['subtopics'].add({
                          'topic': 'New Subtopic',
                          'estimated_time': 15,
                          'importance': 3,
                          'difficulty': 2,
                          'resources': [],
                          'subtopics': [],
                        });
                      });
                      _saveToPrefs();
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalTime = units.fold<int>(
      0,
      (sum, u) => sum + ((u['total_estimated_time'] ?? 0) as num).toInt(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Syllabus'),
        actions: [
          IconButton(
            icon: Icon(
              showInHours ? Icons.access_time_filled : Icons.timer_outlined,
            ),
            tooltip: "Toggle Time Format",
            onPressed: () => setState(() => showInHours = !showInHours),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(child: Text("Total: ${formatTime(totalTime)}")),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: units.length,
        itemBuilder: (context, index) {
          final unit = units[index];
          final topics = unit['topics'] as List<dynamic>;

          return ExpansionTile(
            key: ValueKey(unit),
            title: Row(
              children: [
                Expanded(child: Text(unit['unit_name'] ?? "Unnamed Unit")),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editName(unit, "Unit"),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteNode(units, unit),
                ),
              ],
            ),
            subtitle: Text(
              "Total Time: ${formatTime(unit['total_estimated_time'] ?? 0)}",
            ),
            children: [
              ...topics.map((t) => buildTopicEditor(t, topics)).toList(),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add Topic"),
                  onPressed: () {
                    setState(() {
                      topics.add({
                        'topic': 'New Topic',
                        'estimated_time': 15,
                        'importance': 3,
                        'difficulty': 2,
                        'resources': [],
                        'subtopics': [],
                      });
                    });
                    _saveToPrefs();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
