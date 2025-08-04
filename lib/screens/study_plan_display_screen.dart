// lib/screens/study_plan_display_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/study_plan_models.dart';
import '../models/syllabus_analyzer_models.dart'; // Needed for Topic in uncoveredTopics
import 'package:collection/collection.dart'; // Ensure this is imported for firstWhereOrNull
import 'package:shared_preferences/shared_preferences.dart'; // For saving the plan
import 'dart:convert'; // For JSON encoding

// NEW: No direct use of flutter_local_notifications here, but keeping necessary imports for context
// if you later uncomment notification scheduling in study_plan_input_screen.dart
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:dotenv_check/main.dart'; // To access global flutterLocalNotificationsPlugin

class StudyPlanDisplayScreen extends StatefulWidget {
  final StudyPlan plan;

  const StudyPlanDisplayScreen({super.key, required this.plan});

  @override
  State<StudyPlanDisplayScreen> createState() => _StudyPlanDisplayScreenState();
}

class _StudyPlanDisplayScreenState extends State<StudyPlanDisplayScreen> {
  // Use a mutable copy of the sessions list and uncovered topics
  late StudyPlan _currentPlan;
  late List<StudySession> _sessions;
  late List<Topic> _uncoveredTopics;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.plan;
    _sessions = List.from(widget.plan.sessions);
    _uncoveredTopics = List.from(widget.plan.uncoveredTopics);
    _recalculateAllSessionStartTimes(); // This will apply initial times based on generator order
    _recalculatePlanTotals();
  }

  String _formatTime(int minutes) {
    if (minutes < 0) return "N/A";
    final h = minutes ~/ 60;
    final m = minutes % 60;

    String hoursPart = '';
    String minutesPart = '';

    if (h > 0) {
      hoursPart = '${h}h';
    }
    if (m > 0) {
      minutesPart = '${m}m';
    }

    if (h == 0 && m == 0) return '0m';

    return [hoursPart, minutesPart].where((s) => s.isNotEmpty).join(' ');
  }

  void _recalculatePlanTotals() {
    _currentPlan = StudyPlan(
      planTitle: _currentPlan.planTitle,
      totalAllocatedTimeMinutesUserCommitment:
          _currentPlan.totalAllocatedTimeMinutesUserCommitment,
      deadline: _currentPlan.deadline,
      sessions: _sessions,
      totalRevisionTimeMinutes: _sessions
          .where((s) => s.isRevision)
          .fold(0, (sum, s) => sum + s.allocatedTimeMinutes),
      uncoveredTopics: _uncoveredTopics,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _recalculateAllSessionStartTimes() {
    _sessions.sort((a, b) {
      int dateCompare = a.scheduledDate!.compareTo(b.scheduledDate!);
      if (dateCompare != 0) return dateCompare;
      return _sessions.indexOf(a).compareTo(_sessions.indexOf(b));
    });

    final Map<DateTime, List<StudySession>> sessionsByDateTemp = {};
    for (var session in _sessions) {
      if (session.scheduledDate != null) {
        final normalizedDate = DateTime(
          session.scheduledDate!.year,
          session.scheduledDate!.month,
          session.scheduledDate!.day,
        );
        sessionsByDateTemp.putIfAbsent(normalizedDate, () => []).add(session);
      }
    }

    final sortedDates = sessionsByDateTemp.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    for (var day in sortedDates) {
      _recalculateSessionStartTimesForDay(day);
    }
  }

  void _recalculateSessionStartTimesForDay(DateTime day) {
    final List<StudySession> sessionsOnThisDay = _sessions
        .where(
          (s) =>
              s.scheduledDate != null &&
              DateTime(
                    s.scheduledDate!.year,
                    s.scheduledDate!.month,
                    s.scheduledDate!.day,
                  ) ==
                  DateTime(day.year, day.month, day.day),
        )
        .toList();

    sessionsOnThisDay.sort(
      (a, b) => _sessions.indexOf(a).compareTo(_sessions.indexOf(b)),
    );

    TimeOfDay planDailyStartTime = const TimeOfDay(hour: 9, minute: 0);
    final firstSessionOfDayInOriginalPlan = widget.plan.sessions
        .firstWhereOrNull(
          (s) =>
              s.scheduledDate != null &&
              DateTime(
                    s.scheduledDate!.year,
                    s.scheduledDate!.month,
                    s.scheduledDate!.day,
                  ) ==
                  DateTime(day.year, day.month, day.day),
        );
    if (firstSessionOfDayInOriginalPlan != null &&
        firstSessionOfDayInOriginalPlan.scheduledStartTime != null) {
      final parts = firstSessionOfDayInOriginalPlan.scheduledStartTime!.split(
        ':',
      );
      planDailyStartTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    DateTime currentDailyRunningTime = DateTime(
      day.year,
      day.month,
      day.day,
      planDailyStartTime.hour,
      planDailyStartTime.minute,
    );

    for (int i = 0; i < sessionsOnThisDay.length; i++) {
      final session = sessionsOnThisDay[i];
      final globalIndex = _sessions.indexOf(session);

      if (globalIndex != -1) {
        _sessions[globalIndex] = _sessions[globalIndex].copyWith(
          scheduledStartTime: currentDailyRunningTime
              .toLocal()
              .toString()
              .substring(11, 16),
        );
        currentDailyRunningTime = currentDailyRunningTime.add(
          Duration(minutes: session.allocatedTimeMinutes),
        );
      }
    }
  }

  void _deleteSession(StudySession sessionToDelete) {
    setState(() {
      final int globalIndexToDelete = _sessions.indexOf(sessionToDelete);
      if (globalIndexToDelete != -1) {
        _sessions.removeAt(globalIndexToDelete);

        if (!sessionToDelete.isBreak &&
            globalIndexToDelete < _sessions.length) {
          final nextSession = _sessions[globalIndexToDelete];
          if (nextSession.isBreak && nextSession.unitName == 'User Break') {
            _sessions.removeAt(globalIndexToDelete);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session and its break removed.')),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Session removed.')));
          }
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Session removed.')));
        }
      }
      _recalculateAllSessionStartTimes();
      _recalculatePlanTotals();
    });
  }

  // Helper to find the block (session + its trailing break/revision) that needs to be moved
  List<StudySession> _getMovableBlock(int startIndexInGlobalList) {
    if (startIndexInGlobalList < 0 ||
        startIndexInGlobalList >= _sessions.length) {
      return [];
    }
    final List<StudySession> block = [_sessions[startIndexInGlobalList]];
    final StudySession currentSession = _sessions[startIndexInGlobalList];

    // Check for trailing break
    if (startIndexInGlobalList + 1 < _sessions.length &&
        _sessions[startIndexInGlobalList + 1].isBreak &&
        _sessions[startIndexInGlobalList + 1].scheduledDate ==
            currentSession.scheduledDate) {
      block.add(_sessions[startIndexInGlobalList + 1]);
    }

    // Check for trailing revision (which comes after a potential break)
    // Get the index after the current block
    int afterBlockIndex = startIndexInGlobalList + block.length;
    if (afterBlockIndex < _sessions.length &&
        _sessions[afterBlockIndex].isRevision &&
        _sessions[afterBlockIndex].scheduledDate ==
            currentSession.scheduledDate) {
      block.add(_sessions[afterBlockIndex]);
    }

    return block;
  }

  void _moveSessionUp(int currentIndex, List<StudySession> sessionsForDay) {
    // Only allow moving if the current session is a topic or revision (not a break)
    if (sessionsForDay[currentIndex].isBreak ||
        sessionsForDay[currentIndex].isRevision) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Breaks and Revision sessions cannot be moved independently. Topics move over them.',
          ),
        ),
      );
      return;
    }

    final sessionToMove = sessionsForDay[currentIndex];
    final int globalIndexToMoveStart = _sessions.indexOf(sessionToMove);

    if (globalIndexToMoveStart <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot move further up (already at the top).'),
        ),
      );
      return;
    }

    final List<StudySession> blockToMove = _getMovableBlock(
      globalIndexToMoveStart,
    );
    if (blockToMove.isEmpty) return;

    // Find the target insertion point: the first non-break, non-revision session before current one
    int targetGlobalIndexForSearch = globalIndexToMoveStart - 1;
    StudySession? potentialTargetSession;

    while (targetGlobalIndexForSearch >= 0) {
      potentialTargetSession = _sessions[targetGlobalIndexForSearch];
      if (!potentialTargetSession.isBreak &&
          !potentialTargetSession.isRevision) {
        break; // Found a movable session
      }
      targetGlobalIndexForSearch--;
    }

    if (targetGlobalIndexForSearch >= 0 &&
        potentialTargetSession != null &&
        potentialTargetSession.scheduledDate == sessionToMove.scheduledDate) {
      final StudySession actualTargetSession = potentialTargetSession;

      setState(() {
        // Remove the block from its current position
        _sessions.removeRange(
          globalIndexToMoveStart,
          globalIndexToMoveStart + blockToMove.length,
        );

        final int newGlobalTargetIndex = _sessions.indexOf(actualTargetSession);

        _sessions.insertAll(newGlobalTargetIndex, blockToMove);

        _recalculateAllSessionStartTimes();
        _recalculatePlanTotals();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session moved up.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot move further up (only fixed sessions or start of day).',
          ),
        ),
      );
    }
  }

  void _moveSessionDown(int currentIndex, List<StudySession> sessionsForDay) {
    if (sessionsForDay[currentIndex].isBreak) {
      // Only allow topics/revision to move, not breaks
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Breaks cannot be moved. Topics and Revision sessions move over them.',
          ),
        ),
      );
      return;
    }

    final sessionToMove = sessionsForDay[currentIndex];
    final int globalIndexToMoveStart = _sessions.indexOf(sessionToMove);

    final List<StudySession> blockToMove = _getMovableBlock(
      globalIndexToMoveStart,
    );
    if (blockToMove.isEmpty) return;

    // Check if moving down is possible within the same day
    if (globalIndexToMoveStart + blockToMove.length >= _sessions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot move further down (end of plan).'),
        ),
      );
      return;
    }
    if (_sessions[globalIndexToMoveStart + blockToMove.length].scheduledDate !=
        sessionToMove.scheduledDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot move further down (end of day).')),
      );
      return;
    }

    // Find the target insertion point: the first non-break session after current one
    int targetGlobalIndexForSearch =
        globalIndexToMoveStart +
        blockToMove.length; // Start search AFTER the block being moved
    StudySession? potentialTargetSession;
    if (targetGlobalIndexForSearch < _sessions.length) {
      potentialTargetSession = _sessions[targetGlobalIndexForSearch];
    }

    while (targetGlobalIndexForSearch < _sessions.length) {
      if (potentialTargetSession!.isBreak) {
        // It's a fixed session (break)
        targetGlobalIndexForSearch++; // Skip it
        if (targetGlobalIndexForSearch < _sessions.length) {
          potentialTargetSession = _sessions[targetGlobalIndexForSearch];
        } else {
          potentialTargetSession = null; // Reached end of list
        }
      } else {
        // Found a movable session (Topic or Revision)
        break;
      }
    }

    if (targetGlobalIndexForSearch < _sessions.length &&
        potentialTargetSession != null &&
        potentialTargetSession.scheduledDate == sessionToMove.scheduledDate) {
      final StudySession actualTargetSession = potentialTargetSession;

      setState(() {
        // Remove the block from its current position
        _sessions.removeRange(
          globalIndexToMoveStart,
          globalIndexToMoveStart + blockToMove.length,
        );

        // Calculate the new insertion index after removal.
        final int newGlobalTargetIndex = _sessions.indexOf(actualTargetSession);
        // Insert the block *after* the target session's block (target session + its potential trailing break)
        int insertAfterTargetIndex =
            newGlobalTargetIndex +
            _getMovableBlock(newGlobalTargetIndex).length;

        _sessions.insertAll(insertAfterTargetIndex, blockToMove);

        _recalculateAllSessionStartTimes();
        _recalculatePlanTotals();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session moved down.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot move further down (only fixed sessions or end of day).',
          ),
        ),
      );
    }
  }

  void _addTopicRevision(StudySession parentTopicSession) async {
    final TextEditingController timeController = TextEditingController(
      text: '30',
    );
    final newTime = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Revision for ${parentTopicSession.topic?.topic} (minutes)',
        ),
        content: TextField(
          controller: timeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter minutes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(timeController.text) ?? 0),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newTime != null && newTime > 0) {
      setState(() {
        final newRevisionSession = StudySession(
          unitName:
              'Revision for ${parentTopicSession.topic?.topic ?? 'Topic'}',
          topic: parentTopicSession.topic,
          allocatedTimeMinutes: newTime,
          scheduledDate: parentTopicSession.scheduledDate,
          isRevision: true,
          isBreak: false,
          scheduledStartTime: null, // Will be recalculated
        );

        final int parentIndex = _sessions.indexOf(parentTopicSession);
        // Insert new session immediately after the parent topic session AND its break if it has one
        int insertIndex = parentIndex;
        if (parentIndex + 1 < _sessions.length &&
            _sessions[parentIndex + 1].isBreak &&
            _sessions[parentIndex + 1].scheduledDate ==
                parentTopicSession.scheduledDate) {
          insertIndex = parentIndex + 1; // Insert after parent topic's break
        }
        _sessions.insert(
          insertIndex + 1,
          newRevisionSession,
        ); // Insert after the block

        _recalculateAllSessionStartTimes();
        _recalculatePlanTotals();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $newTime mins revision for ${parentTopicSession.topic?.topic ?? 'topic'}.',
          ),
        ),
      );
    }
  }

  void _addBreakAfterSession(StudySession parentSession) async {
    final TextEditingController timeController = TextEditingController(
      text: '5',
    );
    final newTime = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Break After ${parentSession.topic?.topic ?? parentSession.unitName} (minutes)',
        ),
        content: TextField(
          controller: timeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter minutes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(timeController.text) ?? 0),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newTime != null && newTime > 0) {
      setState(() {
        final newBreakSession = StudySession(
          unitName: 'User Break',
          topic: null,
          allocatedTimeMinutes: newTime,
          scheduledDate: parentSession.scheduledDate,
          isRevision: false,
          isBreak: true,
          scheduledStartTime: null, // Will be recalculated
        );

        final int parentIndex = _sessions.indexOf(parentSession);
        // Insert new break session immediately after the parent session (and its existing break if it has one)
        int insertIndex = parentIndex;
        if (parentIndex + 1 < _sessions.length &&
            _sessions[parentIndex + 1].isBreak &&
            _sessions[parentIndex + 1].scheduledDate ==
                parentSession.scheduledDate) {
          insertIndex = parentIndex + 1; // Insert after the existing break
        }
        _sessions.insert(
          insertIndex + 1,
          newBreakSession,
        ); // Insert after the block

        _recalculateAllSessionStartTimes();
        _recalculatePlanTotals();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $newTime mins break after session.')),
      );
    }
  }

  void _editSessionTime(StudySession sessionToEdit, String sessionType) async {
    final TextEditingController timeController = TextEditingController(
      text: sessionToEdit.allocatedTimeMinutes.toString(),
    );
    final newTime = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $sessionType Time (minutes)'),
        content: TextField(
          controller: timeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter new minutes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(timeController.text) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTime != null && newTime >= 0) {
      setState(() {
        final int sessionIndex = _sessions.indexOf(sessionToEdit);
        if (sessionIndex != -1) {
          _sessions[sessionIndex] = _sessions[sessionIndex].copyWith(
            allocatedTimeMinutes: newTime,
          );
          _recalculateAllSessionStartTimes();
          _recalculatePlanTotals();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated $sessionType time to $newTime mins.'),
        ),
      );
    }
  }

  // NEW: _savePlan method (from previous discussion)
  Future<void> _savePlan() async {
    // Show a SnackBar indicating saving process
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide any previous
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving plan...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      // Load existing plans
      final String? savedPlansJsonString = prefs.getString('saved_study_plans');
      List<Map<String, dynamic>> savedPlansRaw = [];
      if (savedPlansJsonString != null && savedPlansJsonString.isNotEmpty) {
        savedPlansRaw = (json.decode(savedPlansJsonString) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }

      // Convert current plan to JSON map
      final Map<String, dynamic> currentPlanJsonMap = _currentPlan.toJson();

      // Check if a plan with the same title already exists and update it
      int existingIndex = savedPlansRaw.indexWhere(
        (element) => element['planTitle'] == _currentPlan.planTitle,
      );

      if (existingIndex != -1) {
        // Update existing plan's data and timestamp
        savedPlansRaw[existingIndex] = {
          'planTitle': _currentPlan.planTitle,
          'planData': currentPlanJsonMap,
          'timestamp': DateTime.now().toIso8601String(),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan updated successfully!')),
        );
      } else {
        // Add new plan
        savedPlansRaw.insert(0, {
          'planTitle': _currentPlan.planTitle,
          'planData': currentPlanJsonMap,
          'timestamp': DateTime.now().toIso8601String(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan saved successfully!')),
        );
      }

      // Limit the number of saved plans if desired (e.g., max 10)
      if (savedPlansRaw.length > 20) {
        // Keep last 20 plans
        savedPlansRaw = savedPlansRaw.sublist(0, 20);
      }

      // Save the updated list back to SharedPreferences
      await prefs.setString('saved_study_plans', json.encode(savedPlansRaw));
      print('DEBUG: Study plan saved: ${_currentPlan.planTitle}');
    } catch (e, stacktrace) {
      print('Error saving plan: $e');
      print('Stacktrace: $stacktrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set alarm: ${e.toString()}')),
      );
    }
  }

  // NEW: _setCustomAlarm method (from previous discussion)
  Future<void> _setCustomAlarm() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      final now = DateTime.now();
      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'custom_alarm_channel_id',
            'Custom Alarms',
            channelDescription: 'Custom alarms set by the user',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'Custom Alarm',
          );
      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      try {
        // await flutterLocalNotificationsPlugin.zonedSchedule( // Commented out as per user's request
        //   0, // Use a fixed ID for the custom alarm if only one is allowed
        //   'Custom Study Alarm',
        //   'It\'s time for your custom study reminder!',
        //   tz.TZDateTime.from(scheduledDate, tz.local),
        //   platformDetails,
        //   uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        //   matchDateTimeComponents: DateTimeComponents.time, // Alarm should repeat daily at this time
        //   payload: 'custom_alarm',
        // );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alarm set for ${pickedTime.format(context)}! (Notifications disabled)',
            ),
          ),
        );
        print(
          'DEBUG: Custom alarm set for ${scheduledDate.toLocal()} (Notifications disabled)',
        );
      } catch (e) {
        print('Error setting custom alarm: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to set alarm: ${e.toString()} (Notifications disabled)',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group sessions by date
    final Map<DateTime, List<StudySession>> sessionsByDate = {};
    for (var session in _sessions) {
      if (session.scheduledDate != null) {
        final normalizedDate = DateTime(
          session.scheduledDate!.year,
          session.scheduledDate!.month,
          session.scheduledDate!.day,
        );
        sessionsByDate.putIfAbsent(normalizedDate, () => []).add(session);
      }
    }

    final sortedDates = sessionsByDate.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    int totalDaysInPlan = sortedDates.length;
    double averageMinutesPerDayInPlan = totalDaysInPlan > 0
        ? _sessions.fold(
                0,
                (sum, session) => sum + session.allocatedTimeMinutes,
              ) /
              totalDaysInPlan
        : 0;
    String averageHoursPerDayInPlan = (averageMinutesPerDayInPlan / 60)
        .toStringAsFixed(1);

    bool extendsBeyondDeadline = false;
    if (sortedDates.isNotEmpty) {
      final lastScheduledDate = sortedDates.last;
      if (lastScheduledDate.isAfter(_currentPlan.deadline)) {
        extendsBeyondDeadline = true;
      }
    }

    int totalScheduledTopicMinutes = _sessions
        .where((s) => !s.isRevision && !s.isBreak)
        .fold(0, (sum, session) => sum + session.allocatedTimeMinutes);

    int totalScheduledBreakMinutes = _sessions
        .where((s) => s.isBreak)
        .fold(0, (sum, session) => sum + session.allocatedTimeMinutes);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentPlan.planTitle),
            Text(
              'Target Deadline: ${_currentPlan.deadline.toLocal().year}-${_currentPlan.deadline.toLocal().month.toString().padLeft(2, '0')}-${_currentPlan.deadline.toLocal().day.toString().padLeft(2, '0')}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        // FIX: Wrapped body Column in SingleChildScrollView
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Time Committed (by you until deadline): ${_formatTime(_currentPlan.totalAllocatedTimeMinutesUserCommitment)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Total Topics Scheduled: ${_formatTime(totalScheduledTopicMinutes)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Total Revision Scheduled: ${_formatTime(_currentPlan.totalRevisionTimeMinutes)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Total Breaks Scheduled: ${_formatTime(totalScheduledBreakMinutes)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Total Days in Plan: $totalDaysInPlan days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'Average Hours/Day (scheduled): $averageHoursPerDayInPlan hours',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (extendsBeyondDeadline)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Note: This plan extends beyond your target deadline to cover all material. Consider adjusting daily time or deadline.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (_uncoveredTopics.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uncovered Topics by Deadline (Please increase daily study or extend deadline):',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._uncoveredTopics.map(
                        (topic) => Text(
                          '• ${topic.topic} (${_formatTime(topic.estimatedTime)} remaining)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              // Save and Alarm Buttons
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _savePlan,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Plan'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _setCustomAlarm,
                      icon: const Icon(Icons.alarm),
                      label: const Text('Set Custom Alarm'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // FIX: Removed Expanded from ListView.builder and set shrinkWrap/physics
              // The ListView will now scroll as part of the outer SingleChildScrollView
              ListView.builder(
                shrinkWrap:
                    true, // Crucial for ListView inside SingleChildScrollView
                physics:
                    const NeverScrollableScrollPhysics(), // Delegate scrolling to parent
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  final date = sortedDates[index];
                  final sessionsForDay = sessionsByDate[date]!;
                  final totalTimeForDay = sessionsForDay.fold<int>(
                    0,
                    (sum, session) => sum + session.allocatedTimeMinutes,
                  );

                  bool isPastDeadlineDay = date.isAfter(_currentPlan.deadline);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 3,
                    color: isPastDeadlineDay ? Colors.red.shade50 : null,
                    child: ExpansionTile(
                      title: Text(
                        '${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-${date.toLocal().day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isPastDeadlineDay
                                  ? Colors.red.shade800
                                  : null,
                            ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total for day: ${_formatTime(totalTimeForDay)}',
                          ),
                          if (isPastDeadlineDay)
                            Text(
                              ' (Past Deadline)',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                        ],
                      ),
                      children: sessionsForDay.map((session) {
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4.0,
                            horizontal: 8.0,
                          ),
                          elevation: 1,
                          child: ExpansionTile(
                            key: PageStorageKey(session.hashCode),
                            leading: session.isBreak
                                ? const Icon(
                                    Icons.pause_circle_filled,
                                    color: Colors.green,
                                  )
                                : session.isRevision
                                ? const Icon(
                                    Icons.refresh,
                                    color: Colors.blueGrey,
                                  )
                                : const Icon(Icons.book),
                            title: Text(
                              session.isBreak
                                  ? 'Break Time!'
                                  : session.isRevision
                                  ? 'Revision Session'
                                  : session.topic?.topic ?? 'Unknown Topic',
                            ),
                            subtitle: Text(
                              '${session.scheduledStartTime != null ? '${session.scheduledStartTime} - ' : ''}'
                              '${session.unitName} - ${_formatTime(session.allocatedTimeMinutes)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Disable move buttons for break and revision sessions
                                if (!session.isBreak && !session.isRevision)
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward),
                                    onPressed:
                                        sessionsForDay.indexOf(session) > 0
                                        ? () => _moveSessionUp(
                                            sessionsForDay.indexOf(session),
                                            sessionsForDay,
                                          )
                                        : null,
                                  ),
                                if (!session.isBreak && !session.isRevision)
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward),
                                    onPressed:
                                        sessionsForDay.indexOf(session) <
                                            sessionsForDay.length - 1
                                        ? () => _moveSessionDown(
                                            sessionsForDay.indexOf(session),
                                            sessionsForDay,
                                          )
                                        : null,
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteSession(session),
                                ),
                              ],
                            ),
                            children: [
                              session.isBreak
                                  ? const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('Time to rest and recharge!'),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (session.topic != null) ...[
                                            Text(
                                              'Importance: ${session.topic!.importance}, Difficulty: ${session.topic!.difficulty}',
                                            ),
                                            if (session
                                                .topic!
                                                .timeReasoning
                                                .isNotEmpty)
                                              Text(
                                                'Reasoning: ${session.topic!.timeReasoning}',
                                              ),
                                            if (session
                                                .topic!
                                                .resources
                                                .isNotEmpty)
                                              Text(
                                                'Resources: ${session.topic!.resources.join(', ')}',
                                              ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _addTopicRevision(
                                                          session,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.history,
                                                    ),
                                                    label: const Text(
                                                      'Add Topic Revision',
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 8,
                                                          ),
                                                      textStyle:
                                                          const TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _addBreakAfterSession(
                                                          session,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.free_breakfast,
                                                    ),
                                                    label: const Text(
                                                      'Add Break',
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 8,
                                                          ),
                                                      textStyle:
                                                          const TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else if (session.isRevision) ...[
                                            const Text(
                                              'General review of covered material.',
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () => _editSessionTime(
                                                session,
                                                'Revision',
                                              ),
                                              icon: const Icon(Icons.edit),
                                              label: const Text(
                                                'Edit Revision Time',
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
