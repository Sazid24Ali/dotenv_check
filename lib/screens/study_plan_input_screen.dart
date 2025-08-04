// lib/screens/study_plan_input_screen.dart
import 'package:flutter/material.dart';
import '../models/syllabus_analyzer_models.dart';
import '../models/study_plan_models.dart';
import '../services/study_plan_service.dart'; // Using a new service
import 'study_plan_display_screen.dart';

class StudyPlanInputScreen extends StatefulWidget {
  final SyllabusAnalysisResponse syllabus;

  const StudyPlanInputScreen({super.key, required this.syllabus});

  @override
  State<StudyPlanInputScreen> createState() => _StudyPlanInputScreenState();
}

class _StudyPlanInputScreenState extends State<StudyPlanInputScreen> {
  final _formKey = GlobalKey<FormState>();
  int _days = 30;
  double _hours = 4.0;
  bool _isLoading = false;
  
  // --- NEW STATE VARIABLES FOR ALARM ---
  bool _scheduleDailyAlarm = false;
  TimeOfDay _dailyAlarmTime = const TimeOfDay(hour: 9, minute: 0);
  // ------------------------------------

  void _generatePlan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        final List<Topic> allTopics = [];
        for (var unit in widget.syllabus.units) {
          allTopics.addAll(unit.topics);
        }

        // Generate the plan
        final plan = StudyPlanService.generateStudyPlan(
          topics: allTopics,
          totalDays: _days,
          hoursPerDay: _hours,
        );

        // Schedule alarms if the toggle was on
        if (_scheduleDailyAlarm) {
          await StudyPlanService.scheduleDailyAlarms(plan, _dailyAlarmTime);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Plan generated and daily alarms set for ${_dailyAlarmTime.format(context)}!'),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => StudyPlanDisplayScreen(plan: plan),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to generate plan: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // --- NEW METHOD TO PICK ALARM TIME ---
  Future<void> _pickAlarmTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dailyAlarmTime,
    );
    if (picked != null && picked != _dailyAlarmTime) {
      setState(() {
        _dailyAlarmTime = picked;
      });
    }
  }
  // ------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Schedule'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'How much time do you have?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: _days.toString(),
                decoration: const InputDecoration(
                  labelText: 'Total Number of Days to Study',
                  border: OutlineInputBorder(),
                  suffixText: 'days',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      int.tryParse(value) == null ||
                      int.parse(value) <= 0) {
                    return 'Please enter a valid number of days';
                  }
                  return null;
                },
                onSaved: (value) {
                  _days = int.parse(value!);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _hours.toString(),
                decoration: const InputDecoration(
                  labelText: 'Hours Per Day',
                  border: OutlineInputBorder(),
                  suffixText: 'hours',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Please enter a valid number of hours';
                  }
                  return null;
                },
                onSaved: (value) {
                  _hours = double.parse(value!);
                },
              ),
              const SizedBox(height: 24),
              
              // --- NEW ALARM TOGGLE AND TIME PICKER UI ---
              const Divider(),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Set Daily Study Time Alarm'),
                value: _scheduleDailyAlarm,
                onChanged: (bool value) {
                  setState(() {
                    _scheduleDailyAlarm = value;
                  });
                },
              ),
              if (_scheduleDailyAlarm)
                ListTile(
                  title: const Text('Alarm Time'),
                  trailing: Text(
                    _dailyAlarmTime.format(context),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onTap: _pickAlarmTime,
                ),
              const SizedBox(height: 16),
              const Divider(),
              // ------------------------------------

              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _generatePlan,
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Generate Study Plan'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}