// lib/screens/study_plan_display_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_plan_models.dart';
import '../utils/study_plan_generator.dart';
import 'main_screen.dart';

class StudyPlanDisplayScreen extends StatefulWidget {
  final StudyPlan plan;
  final bool scheduleAlarm;
  final TimeOfDay? alarmTime;

  const StudyPlanDisplayScreen({
    super.key,
    required this.plan,
    this.scheduleAlarm = false,
    this.alarmTime,
  });

  @override
  State<StudyPlanDisplayScreen> createState() => _StudyPlanDisplayScreenState();
}

class _StudyPlanDisplayScreenState extends State<StudyPlanDisplayScreen> {
  bool _isSaving = false;
  late StudyPlan _editablePlan;
  Map<DateTime, List<StudySession>> _sessionsByDate = {};

  @override
  void initState() {
    super.initState();
    _editablePlan = StudyPlan.fromJson(
      json.decode(json.encode(widget.plan.toJson())),
    );
    _groupSessionsByDate();
  }

  void _groupSessionsByDate() {
    _sessionsByDate = {};
    for (var session in _editablePlan.sessions) {
      final date = DateTime(
        session.scheduledDate!.year,
        session.scheduledDate!.month,
        session.scheduledDate!.day,
      );
      if (_sessionsByDate[date] == null) {
        _sessionsByDate[date] = [];
      }
      _sessionsByDate[date]!.add(session);
    }
    setState(() {});
  }

  String _createUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(9999).toString();
  }

  void _addSession(DateTime date, {bool isBreak = false}) {
    final newSession = StudySession(
      id: _createUniqueId(),
      unitName: isBreak ? "Break" : "Revision",
      allocatedTimeMinutes: isBreak ? 10 : 30,
      scheduledDate: date,
      isBreak: isBreak,
      isRevision: !isBreak,
    );
    _editablePlan.sessions.add(newSession);
    _groupSessionsByDate();
  }

  void _deleteSession(String sessionId) {
    _editablePlan.sessions.removeWhere((session) => session.id == sessionId);
    _groupSessionsByDate();
  }

  Future<void> _savePlan() async {
    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.scheduleAlarm && widget.alarmTime != null) {
        await StudyPlanGenerator.scheduleDailyAlarms(
          _editablePlan,
          widget.alarmTime!,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Plan saved and alarms set for ${widget.alarmTime!.format(context)}!',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan saved successfully!')),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final String? savedPlansJson = prefs.getString('saved_study_plans');
      final List<dynamic> savedPlans = savedPlansJson != null
          ? json.decode(savedPlansJson)
          : [];
      final planData = {
        'planTitle': _editablePlan.planTitle,
        'timestamp': DateTime.now().toIso8601String(),
        'planData': _editablePlan.toJson(),
      };
      savedPlans.add(planData);
      await prefs.setString('saved_study_plans', json.encode(savedPlans));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save plan: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isSaving = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedDates = _sessionsByDate.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editablePlan.planTitle),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _savePlan,
                  tooltip: 'Save Plan',
                ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final sessionsForDay = _sessionsByDate[date]!;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(date),
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(fontSize: 20),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.coffee_outlined,
                              color: Colors.brown,
                            ),
                            tooltip: "Add Break",
                            onPressed: () => _addSession(date, isBreak: true),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.lightbulb_outline,
                              color: Colors.orange,
                            ),
                            tooltip: "Add Revision",
                            onPressed: () => _addSession(date),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final session = sessionsForDay.removeAt(oldIndex);
                      sessionsForDay.insert(newIndex, session);
                    });
                  },
                  children: sessionsForDay
                      .map((session) => buildSessionTile(session))
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildSessionTile(StudySession session) {
    if (session.isBreak || session.isRevision) {
      return ListTile(
        key: ValueKey(session.id),
        leading: Icon(
          session.isBreak ? Icons.coffee : Icons.book,
          color: session.isBreak ? Colors.brown : Colors.orange,
        ),
        title: Text(
          session.isBreak ? "Break" : "Revision",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${session.allocatedTimeMinutes} minutes'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 22, color: Colors.grey),
          onPressed: () => _deleteSession(session.id),
        ),
      );
    }

    return ExpansionTile(
      key: ValueKey(session.id),
      leading: const Icon(Icons.school, color: Colors.indigo),
      title: Text(
        session.topic?.topic ?? "Unnamed Topic",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${session.allocatedTimeMinutes} minutes'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text('Importance: ${session.topic?.importance ?? 'N/A'}'),
              Text('Difficulty: ${session.topic?.difficulty ?? 'N/A'}'),
            ],
          ),
        ),
      ],
    );
  }
}
