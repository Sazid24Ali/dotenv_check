// lib/screens/study_plan_input_screen.dart
import 'package:flutter/material.dart';
import 'dart:math'; // Import for the 'max' function
import '../models/syllabus_analyzer_models.dart'; // To get syllabus details
import '../models/study_plan_models.dart'; // To use StudyPlan model
import '../utils/study_plan_generator.dart'; // To use StudyPlanGenerator
import 'study_plan_display_screen.dart'; // To navigate to display screen

class StudyPlanInputScreen extends StatefulWidget {
  final SyllabusAnalysisResponse syllabus; // The parsed syllabus data

  const StudyPlanInputScreen({super.key, required this.syllabus});

  @override
  State<StudyPlanInputScreen> createState() => _StudyPlanInputScreenState();
}

class _StudyPlanInputScreenState extends State<StudyPlanInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _hoursPerDayController =
      TextEditingController(); // Changed to hours per day
  DateTime _selectedDeadline = DateTime.now().add(
    const Duration(days: 7),
  ); // Default to 1 week from now
  String _planTitle = 'My Study Plan';

  @override
  void initState() {
    super.initState();
    _planTitle =
        '${widget.syllabus.courseTitle.isNotEmpty ? widget.syllabus.courseTitle : 'General'} Study Plan';
    // Pre-fill average hours using null-aware operator for totalEstimatedTimeForSyllabus
    // totalEstimatedTimeForSyllabus is now guaranteed non-null due to defaultValue: 0
    if (widget.syllabus.totalEstimatedTimeForSyllabus > 0) {
      int daysToDeadline = max(
        1,
        _selectedDeadline.difference(DateTime.now()).inDays,
      );
      double avgMinutesPerDay =
          widget.syllabus.totalEstimatedTimeForSyllabus / daysToDeadline;
      _hoursPerDayController.text = (avgMinutesPerDay / 60).toStringAsFixed(
        1,
      ); // Suggest average hours per day
    } else {
      _hoursPerDayController.text =
          '1.0'; // Default to 1 hour if total syllabus time is 0
    }
  }

  @override
  void dispose() {
    _hoursPerDayController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365 * 2),
      ), // 2 years from now
    );
    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
        // Recalculate suggested hours per day if deadline changes
        if (widget.syllabus.totalEstimatedTimeForSyllabus > 0) {
          int daysToDeadline = max(
            1,
            _selectedDeadline.difference(DateTime.now()).inDays,
          );
          double avgMinutesPerDay =
              widget.syllabus.totalEstimatedTimeForSyllabus / daysToDeadline;
          _hoursPerDayController.text = (avgMinutesPerDay / 60).toStringAsFixed(
            1,
          );
        } else {
          _hoursPerDayController.text = '1.0';
        }
      });
    }
  }

  void _generateStudyPlan() {
    if (_formKey.currentState!.validate()) {
      final double hoursPerDay = double.parse(_hoursPerDayController.text);
      final int minutesPerDay = (hoursPerDay * 60).round();

      if (minutesPerDay <= 0) {
        _showErrorDialog(
          'Invalid Time',
          'Please allocate a positive amount of study time per day.',
        );
        return;
      }

      final int daysToDeadline = max(
        1, // Ensure at least 1 day for calculations, even if deadline is today or past
        _selectedDeadline.difference(DateTime.now()).inDays,
      );
      final int totalAllocatedTimeMinutes = minutesPerDay * daysToDeadline;

      if (totalAllocatedTimeMinutes <= 0) {
        _showErrorDialog(
          'Invalid Plan Duration',
          'Total study time for the plan is zero. Adjust hours per day or deadline.',
        );
        return;
      }

      // Generate the plan using the Knapsack logic
      final StudyPlan generatedPlan = StudyPlanGenerator.generatePlan(
        syllabus: widget.syllabus,
        planTitle: _planTitle,
        totalAllocatedTimeMinutes:
            totalAllocatedTimeMinutes, // Use calculated total
        deadline: _selectedDeadline,
        minutesPerDay: minutesPerDay, // Pass minutes per day for distribution
      );

      if (generatedPlan.sessions.isEmpty) {
        _showErrorDialog(
          'No Plan Generated',
          'No study sessions could be generated. This might happen if '
              'the total allocated time (${totalAllocatedTimeMinutes} mins) is too low, or if all topics have 0 estimated time after filtering. '
              'Please try increasing the hours per day, extending the deadline, or ensure your syllabus topics have estimated times.',
        );
        return;
      }

      // Navigate to the display screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudyPlanDisplayScreen(plan: generatedPlan),
        ),
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Study Plan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Plan for: ${widget.syllabus.courseTitle.isNotEmpty ? widget.syllabus.courseTitle : 'Unnamed Course'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Total Syllabus Estimated Time: ${widget.syllabus.totalEstimatedTimeForSyllabus} minutes', // Safely display
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _hoursPerDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Study Hours per Day', // Changed label
                  hintText: 'e.g., 2.5 (for 2 hours 30 mins)', // Changed hint
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter study hours per day.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number (e.g., 2.5).';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Hours must be positive.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Deadline'),
                subtitle: Text(
                  '${_selectedDeadline.toLocal().year}-${_selectedDeadline.toLocal().month.toString().padLeft(2, '0')}-${_selectedDeadline.toLocal().day.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDeadline(context),
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: _planTitle,
                decoration: const InputDecoration(
                  labelText: 'Plan Title',
                  hintText: 'e.g., "Midterm Prep"',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _planTitle = value;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _generateStudyPlan,
                icon: const Icon(Icons.school),
                label: const Text('Generate Study Plan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
