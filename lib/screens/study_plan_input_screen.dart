// lib/screens/study_plan_input_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <-- THIS LINE FIXES THE ERROR
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
  final TextEditingController _breakMinutesController = TextEditingController();

  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 28));
  String _planTitle = 'My Study Plan';
  TimeOfDay _dailyStudyStartTime = const TimeOfDay(hour: 9, minute: 0);

  // State for calculated values
  int _calculatedDaysToDeadline = 0;
  String _suggestedTotalDailyHoursDisplay = '';

  // State for new features
  bool _scheduleDailyAlarm = false;

  @override
  void initState() {
    super.initState();
    _planTitle =
        '${widget.syllabus.courseTitle.isNotEmpty ? widget.syllabus.courseTitle : 'Unnamed Course'} Study Plan';
    _revisionMinutesPerDayController.text = '30';
    _breakMinutesController.text = '10';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateCalculatedDisplayValues();
      }
    });
  }

  @override
  void dispose() {
    _studyHoursPerDayController.dispose();
    _revisionMinutesPerDayController.dispose();
    _breakMinutesController.dispose();
    super.dispose();
  }

  int _calculateDaysBetweenInclusive(DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.difference(start).inDays + 1;
  }

  void _updateCalculatedDisplayValues() {
    if (widget.syllabus.totalEstimatedTimeForSyllabus <= 0) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDateOnly = DateTime(
      _selectedDeadline.year,
      _selectedDeadline.month,
      _selectedDeadline.day,
    );
    DateTime planningStartDate = (now.hour >= 20)
        ? today.add(const Duration(days: 1))
        : today;
    int daysAvailable = _calculateDaysBetweenInclusive(
      planningStartDate,
      deadlineDateOnly,
    );

    final int revisionMinutesPerDay =
        int.tryParse(_revisionMinutesPerDayController.text) ?? 0;
    final int totalTopicsMinutes =
        widget.syllabus.totalEstimatedTimeForSyllabus;
    final int totalRevisionMinutes = revisionMinutesPerDay * daysAvailable;
    final int totalWorkloadMinutes = totalTopicsMinutes + totalRevisionMinutes;
    double averageTotalDailyMinutesNeeded = daysAvailable > 0
        ? totalWorkloadMinutes / daysAvailable
        : 0;
    double suggestedMinutesPerDayForTopics =
        averageTotalDailyMinutesNeeded - revisionMinutesPerDay;

    if (suggestedMinutesPerDayForTopics < 0)
      suggestedMinutesPerDayForTopics = 0;

    if (mounted) {
      setState(() {
        _calculatedDaysToDeadline = daysAvailable;
        _suggestedTotalDailyHoursDisplay =
            ((suggestedMinutesPerDayForTopics + revisionMinutesPerDay) / 60)
                .toStringAsFixed(1);
        _studyHoursPerDayController.text =
            (suggestedMinutesPerDayForTopics / 60).toStringAsFixed(1);
      });
    }
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
      });
    }
  }

  void _generateStudyPlan() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final double studyHoursPerDay =
          double.tryParse(_studyHoursPerDayController.text) ?? 0;
      final int minutesPerDayForTopics = (studyHoursPerDay * 60).round();
      final int revisionMinutesPerDay =
          int.tryParse(_revisionMinutesPerDayController.text) ?? 0;
      final int breakMinutes = int.tryParse(_breakMinutesController.text) ?? 0;
      final int daysForCalculatedTotal = _calculatedDaysToDeadline;
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
        breakMinutes: breakMinutes,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudyPlanDisplayScreen(
            plan: generatedPlan,
            scheduleAlarm: _scheduleDailyAlarm,
            alarmTime: _dailyStudyStartTime,
          ),
        ),
      );
    }
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
                'Plan for: ${widget.syllabus.courseTitle}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Total Estimated Time: ${widget.syllabus.totalEstimatedTimeForSyllabus} minutes',
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Your Daily Topics Study (Hours)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null ||
                        value.isEmpty ||
                        double.tryParse(value) == null ||
                        double.parse(value) < 0)
                    ? 'Enter a valid number of hours.'
                    : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _revisionMinutesPerDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Your Daily Revision (Minutes)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _updateCalculatedDisplayValues(),
                validator: (value) =>
                    (value == null ||
                        value.isEmpty ||
                        int.tryParse(value) == null ||
                        int.parse(value) < 0)
                    ? 'Enter valid minutes.'
                    : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _breakMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Break Minutes After Each Session',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null ||
                        value.isEmpty ||
                        int.tryParse(value) == null ||
                        int.parse(value) < 0)
                    ? 'Enter valid minutes.'
                    : null,
              ),
              const SizedBox(height: 20),

              const Divider(),
              SwitchListTile(
                title: const Text('Set Daily Study Start Time Alarm'),
                value: _scheduleDailyAlarm,
                onChanged: (bool value) =>
                    setState(() => _scheduleDailyAlarm = value),
              ),

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
                  DateFormat('yyyy-MM-dd').format(_selectedDeadline),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDeadline(context),
              ),
              const SizedBox(height: 20),

              TextFormField(
                initialValue: _planTitle,
                decoration: const InputDecoration(
                  labelText: 'Plan Title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _planTitle = value,
              ),
              const SizedBox(height: 20),

              const Divider(),

              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _generateStudyPlan,
                icon: const Icon(Icons.school),
                label: const Text('Generate Study Plan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
