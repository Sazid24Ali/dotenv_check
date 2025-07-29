// lib/screens/study_plan_input_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../models/syllabus_analyzer_models.dart';
import '../models/study_plan_models.dart';
import '../utils/study_plan_generator.dart';
import 'study_plan_display_screen.dart';

class StudyPlanInputScreen extends StatefulWidget {
  final SyllabusAnalysisResponse syllabus;

  const StudyPlanInputScreen({super.key, required this.syllabus});

  @override
  State<StudyPlanInputScreen> createState() => _StudyPlanInputScreenState();
}

class _StudyPlanInputScreenState extends State<StudyPlanInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _studyHoursPerDayController =
      TextEditingController();
  final TextEditingController _revisionMinutesPerDayController =
      TextEditingController();
  final TextEditingController _dailyStudyStartTimeController =
      TextEditingController();

  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 28));
  String _planTitle = 'My Study Plan';

  int _calculatedDaysToDeadline = 0;
  String _suggestedTotalDailyHoursDisplay = '';
  TimeOfDay _dailyStudyStartTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _planTitle =
        '${widget.syllabus.courseTitle.isNotEmpty ? widget.syllabus.courseTitle : 'General'} Study Plan';

    _revisionMinutesPerDayController.text = '15';
    // FIX: Defer setting _dailyStudyStartTimeController.text until context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dailyStudyStartTimeController.text = _dailyStudyStartTime.format(
        context,
      );
      _updateCalculatedDisplayValues(); // Call this after context is ready
    });
  }

  int _calculateDaysBetweenInclusive(DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.difference(start).inDays + 1;
  }

  void _updateCalculatedDisplayValues() {
    if (widget.syllabus.totalEstimatedTimeForSyllabus > 0) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final deadlineDateOnly = DateTime(
        _selectedDeadline.year,
        _selectedDeadline.month,
        _selectedDeadline.day,
      );

      DateTime planningStartDate = (DateTime.now().hour >= 20)
          ? today.add(const Duration(days: 1))
          : today;

      int daysAvailableForScheduling = _calculateDaysBetweenInclusive(
        planningStartDate,
        deadlineDateOnly,
      );

      final int revisionMinutesPerDay =
          int.tryParse(_revisionMinutesPerDayController.text) ?? 0;

      final int totalTopicsMinutes =
          widget.syllabus.totalEstimatedTimeForSyllabus;
      final int totalRevisionMinutesOverPeriod =
          revisionMinutesPerDay * daysAvailableForScheduling;

      final int totalWorkloadMinutes =
          totalTopicsMinutes + totalRevisionMinutesOverPeriod;

      double averageTotalDailyMinutesNeeded =
          totalWorkloadMinutes / daysAvailableForScheduling;

      double suggestedMinutesPerDayForTopics =
          averageTotalDailyMinutesNeeded - revisionMinutesPerDay;

      if (suggestedMinutesPerDayForTopics < 0)
        suggestedMinutesPerDayForTopics = 0;
      if (suggestedMinutesPerDayForTopics > 0 &&
          suggestedMinutesPerDayForTopics < 30) {
        suggestedMinutesPerDayForTopics = 30;
      }

      // Ensure context is available before formatting TimeOfDay, especially for TimeOfDay.format
      if (mounted) {
        // Check if the widget is still mounted before using context
        setState(() {
          _calculatedDaysToDeadline = daysAvailableForScheduling;
          _suggestedTotalDailyHoursDisplay =
              ((suggestedMinutesPerDayForTopics + revisionMinutesPerDay) / 60)
                  .toStringAsFixed(1);
          _studyHoursPerDayController.text =
              (suggestedMinutesPerDayForTopics / 60).toStringAsFixed(1);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _calculatedDaysToDeadline = _calculateDaysBetweenInclusive(
            (DateTime.now().hour >= 20)
                ? DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ).add(const Duration(days: 1))
                : DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ),
            DateTime(
              _selectedDeadline.year,
              _selectedDeadline.month,
              _selectedDeadline.day,
            ),
          );
          _suggestedTotalDailyHoursDisplay = '1.0';
          _studyHoursPerDayController.text = '1.0';
        });
      }
    }
  }

  @override
  void dispose() {
    _studyHoursPerDayController.dispose();
    _revisionMinutesPerDayController.dispose();
    _dailyStudyStartTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
        _updateCalculatedDisplayValues();
      });
    }
  }

  Future<void> _selectDailyStudyStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _dailyStudyStartTime,
    );
    if (picked != null && picked != _dailyStudyStartTime) {
      setState(() {
        _dailyStudyStartTime = picked;
        _dailyStudyStartTimeController.text = picked.format(context);
        // No need to recalculate overall values just because start time changes
      });
    }
  }

  void _generateStudyPlan() {
    if (_formKey.currentState!.validate()) {
      final double studyHoursPerDay = double.parse(
        _studyHoursPerDayController.text,
      );
      final int minutesPerDayForTopics = (studyHoursPerDay * 60).round();

      final int revisionMinutesPerDay =
          int.tryParse(_revisionMinutesPerDayController.text) ?? 0;

      if (minutesPerDayForTopics <= 0 && revisionMinutesPerDay <= 0) {
        _showErrorDialog(
          'Invalid Daily Time',
          'Please allocate a positive amount of study time or revision time per day.',
        );
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final deadlineDateOnly = DateTime(
        _selectedDeadline.year,
        _selectedDeadline.month,
        _selectedDeadline.day,
      );

      DateTime planningStartDate = (DateTime.now().hour >= 20)
          ? today.add(const Duration(days: 1))
          : today;

      int daysForCalculatedTotal = _calculateDaysBetweenInclusive(
        planningStartDate,
        deadlineDateOnly,
      );
      final int totalAllocatedTimeMinutesForPlan =
          (minutesPerDayForTopics + revisionMinutesPerDay) *
          daysForCalculatedTotal;

      final StudyPlan generatedPlan = StudyPlanGenerator.generatePlan(
        syllabus: widget.syllabus,
        planTitle: _planTitle,
        totalAllocatedTimeMinutesUserCommitment:
            totalAllocatedTimeMinutesForPlan,
        deadline: _selectedDeadline,
        minutesPerDayForTopics: minutesPerDayForTopics,
        revisionMinutesPerDay: revisionMinutesPerDay,
        dailyStudyStartTime: _dailyStudyStartTime,
      );

      if (generatedPlan.sessions.isEmpty &&
          generatedPlan.uncoveredTopics.isNotEmpty) {
        _showErrorDialog(
          'Plan Not Feasible',
          'Your daily study time is too low to schedule any sessions, or all topics have 0 estimated time. '
              'Please increase your daily study hours/minutes or adjust topic times.',
        );
        return;
      }

      bool allTopicsCovered = generatedPlan.uncoveredTopics.isEmpty;
      if (!allTopicsCovered) {
        _showErrorDialog(
          'Plan Incomplete by Deadline',
          'Your current daily study commitment for topics (${_studyHoursPerDayController.text} hours) '
              'plus revision (${_revisionMinutesPerDayController.text} mins) '
              'is insufficient to cover ALL syllabus material by your deadline (${_selectedDeadline.toLocal().toString().substring(0, 10)}). '
              'The plan will show topics covered up to the deadline. Consider increasing daily study time or extending the deadline. '
              'Topics not covered: ${generatedPlan.uncoveredTopics.map((t) => t.topic).join(', ')}',
        );
      }

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
                'Total Syllabus Estimated Time: ${widget.syllabus.totalEstimatedTimeForSyllabus} minutes',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Text(
                'Days available until deadline: $_calculatedDaysToDeadline days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Suggested Total Daily Study: $_suggestedTotalDailyHoursDisplay hours',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _studyHoursPerDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your Daily Topics Study (Hours)',
                  hintText: 'e.g., 2.5 (for 2 hours 30 mins)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter study hours per day.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number (e.g., 2.5).';
                  }
                  if (double.parse(value) < 0) {
                    return 'Hours cannot be negative.';
                  }
                  final int currentRevisionMins =
                      int.tryParse(_revisionMinutesPerDayController.text) ?? 0;
                  if (double.parse(value) == 0 && currentRevisionMins == 0) {
                    return 'Total daily study time cannot be zero.';
                  }
                  return null;
                },
                onChanged: (value) {
                  // No auto-suggestion update on this field change.
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _revisionMinutesPerDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your Daily Revision (Minutes)',
                  hintText: 'e.g., 15 (for 15 minutes)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter revision minutes per day.';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid integer (e.g., 15).';
                  }
                  if (int.parse(value) < 0) {
                    return 'Minutes cannot be negative.';
                  }
                  final double currentTopicHours =
                      double.tryParse(_studyHoursPerDayController.text) ?? 0;
                  if (currentTopicHours == 0 && int.parse(value) == 0) {
                    return 'Total daily study time cannot be zero.';
                  }
                  return null;
                },
                onChanged: (value) {
                  _updateCalculatedDisplayValues(); // Recalculate suggestion when revision minutes are changed
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Daily Study Start Time'),
                subtitle: Text(_dailyStudyStartTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectDailyStudyStartTime(context),
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
