import 'package:flutter/material.dart';
import '../models/syllabus_analyzer_models.dart';
import '../models/study_plan_models.dart';
import '../utils/study_plan_generator.dart';
import 'study_plan_display_screen.dart';

class StudyPlanInputScreen extends StatefulWidget {
  final Syllabus syllabus;

  const StudyPlanInputScreen({super.key, required this.syllabus});

  @override
  State<StudyPlanInputScreen> createState() => _StudyPlanInputScreenState();
}

class _StudyPlanInputScreenState extends State<StudyPlanInputScreen> {
  final _formKey = GlobalKey<FormState>();
  int _days = 30;
  double _hours = 4.0;
  bool _isLoading = false;

  void _generatePlan() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        final List<SubTopic> allTopics = [];
        for (var subject in widget.syllabus.subjects) {
          for (var topic in subject.topics) {
            if (topic.subTopics.isEmpty) {
              allTopics.add(SubTopic(name: topic.topic, description: ''));
            } else {
              allTopics.addAll(topic.subTopics);
            }
          }
        }

        final plan = StudyPlanGenerator.generateStudyPlan(
          topics: allTopics,
          totalDays: _days,
          hoursPerDay: _hours,
        );

        if (mounted) {
          Navigator.of(context).push(
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
