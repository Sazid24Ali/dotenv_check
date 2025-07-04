import 'package:flutter/material.dart';

class TopicEditorScreen extends StatefulWidget {
  final Map<String, dynamic> parsedJson;

  const TopicEditorScreen({super.key, required this.parsedJson});

  @override
  State<TopicEditorScreen> createState() => _TopicEditorScreenState();
}

class _TopicEditorScreenState extends State<TopicEditorScreen> {
  late List<dynamic> units;

  @override
  void initState() {
    super.initState();
    units = widget.parsedJson['units'];
  }

  void _editTopicName(Map<String, dynamic> topic) async {
    final controller = TextEditingController(text: topic['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Topic Name"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter new topic name"),
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
        topic['name'] = newName.trim();
      });
    }
  }

  void _removeTopic(List<dynamic> topicList, Map<String, dynamic> topic) {
    setState(() {
      topicList.remove(topic);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Syllabus Topics')),
      body: ListView.builder(
        itemCount: units.length,
        itemBuilder: (context, unitIndex) {
          final unit = units[unitIndex];
          final List<dynamic> topics = unit['topics'] ?? [];

          return ExpansionTile(
            title: Text(unit['name'] ?? 'Unnamed Unit'),
            children: topics.map<Widget>((topic) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topic['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editTopicName(topic),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeTopic(topics, topic),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Difficulty
                      Row(
                        children: [
                          Text("Difficulty: ${topic['difficulty'] ?? 3}"),
                          Expanded(
                            child: Slider(
                              value: (topic['difficulty'] ?? 3)
                                  .toDouble()
                                  .clamp(1, 5),
                              min: 1,
                              max: 5,
                              divisions: 4,
                              label: "${topic['difficulty']}",
                              onChanged: (val) => setState(() {
                                topic['difficulty'] = val.round();
                              }),
                            ),
                          ),
                        ],
                      ),

                      // Time
                      Row(
                        children: [
                          Text("Time (min): ${topic['estimated_time'] ?? 15}"),
                          Expanded(
                            child: Slider(
                              value: (topic['estimated_time'] ?? 15)
                                  .toDouble()
                                  .clamp(5, 60),
                              min: 5,
                              max: 60,
                              divisions: 11,
                              label: "${topic['estimated_time']}",
                              onChanged: (val) => setState(() {
                                topic['estimated_time'] = val.round();
                              }),
                            ),
                          ),
                        ],
                      ),

                      // Importance
                      Row(
                        children: [
                          Text("Importance: ${topic['importance'] ?? 3}"),
                          Expanded(
                            child: Slider(
                              value: (topic['importance'] ?? 3)
                                  .toDouble()
                                  .clamp(1, 5),
                              min: 1,
                              max: 5,
                              divisions: 4,
                              label: "${topic['importance']}",
                              onChanged: (val) => setState(() {
                                topic['importance'] = val.round();
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
