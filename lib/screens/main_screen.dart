// lib/screens/main_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_plan_models.dart';
import 'syllabus_image_picker.dart';
import 'saved_plans_list_screen.dart';
import 'alarm_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  double _progressPercent = 0.0;
  int _completedTopics = 0;
  int _totalTopics = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final List<String> completedIds =
        prefs.getStringList('completed_topic_ids') ?? [];
    final String? savedPlansJson = prefs.getString('saved_study_plans');

    int totalTopicsCount = 0;
    if (savedPlansJson != null) {
      final List<dynamic> savedPlans = json.decode(savedPlansJson);
      for (var planData in savedPlans) {
        final plan = StudyPlan.fromJson(planData['planData']);
        totalTopicsCount += plan.sessions
            .where((s) => !s.isBreak && !s.isRevision)
            .length;
      }
    }

    setState(() {
      _totalTopics = totalTopicsCount;
      _completedTopics = completedIds.length;
      _progressPercent = _totalTopics > 0
          ? (_completedTopics / _totalTopics)
          : 0.0;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllabus AI Analyzer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProgress,
            tooltip: 'Refresh Progress',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.background,
              const Color.fromARGB(255, 72, 24, 79),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // const Spacer(),
            // Text(
            //   'Your Overall Progress',
            //   style: Theme.of(
            //     context,
            //   ).textTheme.headlineSmall?.copyWith(color: Colors.black54),
            // ),
            const SizedBox(height: 20),
            // _isLoading
            //     ? const CircularProgressIndicator()
            //     : CircularPercentIndicator(
            //         radius: 100.0,
            //         lineWidth: 20.0,
            //         percent: _progressPercent,
            //         center: Text(
            //           '${(_progressPercent * 100).toStringAsFixed(1)}%',
            //           style: const TextStyle(
            //             fontWeight: FontWeight.bold,
            //             fontSize: 32.0,
            //           ),
            //         ),
            //         footer: Padding(
            //           padding: const EdgeInsets.only(top: 10.0),
            //           child: Text(
            //             '$_completedTopics / $_totalTopics Topics Completed',
            //             style: const TextStyle(
            //               fontWeight: FontWeight.bold,
            //               fontSize: 17.0,
            //             ),
            //           ),
            //         ),
            //         circularStrokeCap: CircularStrokeCap.round,
            //         progressColor: Theme.of(context).colorScheme.primary,
            //         backgroundColor: Colors.purple.shade100,
            //       ),
            // const Spacer(),
            _buildMainButton(
              context,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SyllabusImagePicker(),
                ),
              ),
              icon: Icons.document_scanner,
              label: 'Scan Syllabus & Plan',
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedPlansListScreen(),
                ),
              ),
              icon: Icons.list_alt,
              label: 'My Study Plans',
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlarmScreen()),
              ),
              icon: Icons.alarm,
              label: 'My Alarms',
            ),
            const SizedBox(height: 40),
            _buildMainButton(
              context,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlarmScreen()),
              ),
              icon: Icons.show_chart,
              label: 'Track Progress',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      width: 280,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 30),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
      ),
    );
  }
}
