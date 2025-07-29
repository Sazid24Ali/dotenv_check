// lib/utils/study_plan_generator.dart
import 'dart:math';
import '../models/syllabus_analyzer_models.dart';
import '../models/study_plan_models.dart';
import 'package:flutter/material.dart'; // Import for TimeOfDay

class StudyPlanGenerator {
  // Method to generate the study plan using a sequential, time-boxed algorithm
  static StudyPlan generatePlan({
    required SyllabusAnalysisResponse syllabus,
    required String planTitle,
    required int totalAllocatedTimeMinutesUserCommitment,
    required DateTime deadline,
    required int minutesPerDayForTopics,
    required int revisionMinutesPerDay,
    required TimeOfDay dailyStudyStartTime, // Daily study start time
  }) {
    print('DEBUG: --- Study Plan Generation Started (Sequential) ---');
    print('DEBUG: Plan Title: $planTitle');
    print(
      'DEBUG: Total Allocated Time (User Commitment Context): $totalAllocatedTimeMinutesUserCommitment minutes',
    );
    print('DEBUG: Minutes Per Day for Topics: $minutesPerDayForTopics minutes');
    print(
      'DEBUG: Minutes Per Day for Revision: $revisionMinutesPerDay minutes',
    );
    print('DEBUG: Deadline: $deadline');
    // FIX: Removed AlwaysMaterialDirectionality from TimeOfDay format.
    // Format TimeOfDay for debug print using hour and minute directly.
    print(
      'DEBUG: Daily Study Start Time: ${dailyStudyStartTime.hour.toString().padLeft(2, '0')}:${dailyStudyStartTime.minute.toString().padLeft(2, '0')}',
    );
    print(
      'DEBUG: Syllabus Total Estimated Time: ${syllabus.totalEstimatedTimeForSyllabus} minutes',
    );

    List<TopicItem> allTopicItems = _flattenSyllabusToTopicItems(syllabus);

    List<TopicItem> topicsToSchedule = allTopicItems
        .where((item) => item.estimatedTime > 0)
        .map(
          (item) => TopicItem(
            unitName: item.unitName,
            topicObject: item.topicObject,
            estimatedTime: item.estimatedTime,
            importance: item.importance,
            difficulty: item.difficulty,
          ),
        )
        .toList();

    print(
      'DEBUG: Topics to Schedule (after 0-time filter): ${topicsToSchedule.length}',
    );
    for (var item in topicsToSchedule) {
      print(
        'DEBUG:   - Topic: ${item.topicObject.topic}, Time: ${item.estimatedTime}',
      );
    }

    List<StudySession> sessions = [];
    DateTime currentDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    // If it's late in the current day, start planning from tomorrow
    if (DateTime.now().hour >= 20) {
      currentDate = currentDate.add(const Duration(days: 1));
    }

    int topicIndex = 0;

    // The plan will only schedule sessions up to the deadline.
    // Topics not covered will be put into uncoveredTopics list.
    // The loop condition ensures we only schedule UP TO the deadline.
    while (currentDate.isBefore(deadline.add(const Duration(days: 1)))) {
      print(
        'DEBUG: Scheduling for date: ${currentDate.toLocal().toIso8601String().substring(0, 10)}',
      );

      int dailyMinutesUsed =
          0; // Track total minutes used for this specific day

      DateTime currentSessionStartTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        dailyStudyStartTime.hour,
        dailyStudyStartTime.minute,
      );

      // --- 1. Prioritize Topics for the Day ---
      int minutesForTopicsTodayBudget = minutesPerDayForTopics;
      while (minutesForTopicsTodayBudget > 0 &&
          topicIndex < topicsToSchedule.length) {
        TopicItem currentTopicItem = topicsToSchedule[topicIndex];
        int timeToAllocateToTopic = min(
          currentTopicItem.estimatedTime,
          minutesForTopicsTodayBudget,
        );

        if (timeToAllocateToTopic > 0) {
          sessions.add(
            StudySession(
              unitName: currentTopicItem.unitName,
              topic: currentTopicItem.topicObject,
              allocatedTimeMinutes: timeToAllocateToTopic,
              scheduledDate: currentDate,
              isRevision: false,
              scheduledStartTime: currentSessionStartTime
                  .toLocal()
                  .toString()
                  .substring(11, 16), // Format to HH:MM
            ),
          );
          currentTopicItem.estimatedTime -= timeToAllocateToTopic;
          minutesForTopicsTodayBudget -= timeToAllocateToTopic;
          dailyMinutesUsed += timeToAllocateToTopic;
          currentSessionStartTime = currentSessionStartTime.add(
            Duration(minutes: timeToAllocateToTopic),
          ); // Advance start time

          if (currentTopicItem.estimatedTime <= 0) {
            topicIndex++;
          }
        } else {
          break; // No more topic time for today within topic budget
        }
      }

      // --- 2. Allocate Revision for the Day (Only if user specified revision time) ---
      if (revisionMinutesPerDay > 0) {
        bool topicsStillExist = topicIndex < topicsToSchedule.length;
        bool topicsWereScheduledToday = dailyMinutesUsed > 0;

        if (topicsWereScheduledToday || !topicsStillExist) {
          sessions.add(
            StudySession(
              unitName: 'General Revision',
              topic: null,
              allocatedTimeMinutes: revisionMinutesPerDay,
              scheduledDate: currentDate,
              isRevision: true,
              scheduledStartTime: currentSessionStartTime
                  .toLocal()
                  .toString()
                  .substring(11, 16), // Format to HH:MM
            ),
          );
          dailyMinutesUsed += revisionMinutesPerDay;
        }
      }

      if (dailyMinutesUsed == 0 &&
          topicIndex < topicsToSchedule.length &&
          (minutesPerDayForTopics + revisionMinutesPerDay == 0)) {
        print(
          'DEBUG: Daily budget is 0, but topics remain. Advancing date without scheduling.',
        );
      }

      // Move to the next day
      currentDate = currentDate.add(const Duration(days: 1));
    }
    // --- End Scheduling Loop (Strictly adheres to deadline) ---

    // Identify Uncovered Topics (those remaining in topicsToSchedule after the deadline loop)
    List<Topic> uncoveredTopics = [];
    for (int i = topicIndex; i < topicsToSchedule.length; i++) {
      uncoveredTopics.add(topicsToSchedule[i].topicObject);
    }
    // If the last topic was partially scheduled but not fully completed by the deadline
    if (topicIndex < topicsToSchedule.length &&
        topicsToSchedule[topicIndex].estimatedTime > 0) {
      uncoveredTopics.insert(0, topicsToSchedule[topicIndex].topicObject);
    }

    List<StudySession> finalSessions = sessions;

    final int totalScheduledMinutesInPlan = finalSessions.fold(
      0,
      (sum, session) => sum + session.allocatedTimeMinutes,
    );
    final int calculatedTotalRevisionTimeMinutes = finalSessions
        .where((s) => s.isRevision)
        .fold(0, (sum, s) => sum + s.allocatedTimeMinutes);

    finalSessions.sort((a, b) {
      int dateCompare = a.scheduledDate!.compareTo(b.scheduledDate!);
      if (dateCompare != 0) return dateCompare;

      // On the same day: Sort by scheduled start time to maintain daily sequence
      if (a.scheduledStartTime != null && b.scheduledStartTime != null) {
        return a.scheduledStartTime!.compareTo(b.scheduledStartTime!);
      }

      // Secondary: Non-revision sessions before revision sessions if start times are identical
      if (!a.isRevision && b.isRevision) return -1;
      if (a.isRevision && !b.isRevision) return 1;

      return 0; // Maintain current order for other cases
    });

    print(
      'DEBUG: Generated Study Plan with ${finalSessions.length} sessions (including revision).',
    );
    print(
      'DEBUG: User Committed Total Time (up to deadline): $totalAllocatedTimeMinutesUserCommitment minutes',
    );
    print(
      'DEBUG: Total Scheduled Time in Plan: $totalScheduledMinutesInPlan minutes',
    );
    print(
      'DEBUG: Total Revision Time in Plan: $calculatedTotalRevisionTimeMinutes minutes',
    );
    print('DEBUG: Uncovered Topics Count: ${uncoveredTopics.length}');
    print('DEBUG: --- Study Plan Generation Finished ---');

    return StudyPlan(
      planTitle: planTitle,
      totalAllocatedTimeMinutesUserCommitment:
          totalAllocatedTimeMinutesUserCommitment,
      deadline: deadline,
      sessions: finalSessions,
      totalRevisionTimeMinutes: calculatedTotalRevisionTimeMinutes,
      uncoveredTopics: uncoveredTopics,
    );
  }

  // Helper to flatten syllabus hierarchy into a list of individual TopicItems
  static List<TopicItem> _flattenSyllabusToTopicItems(
    SyllabusAnalysisResponse syllabus,
  ) {
    List<TopicItem> flatList = [];
    for (var unit in syllabus.units) {
      _addTopicsRecursively(unit.topics, unit.unitName, flatList);
    }
    return flatList;
  }

  static void _addTopicsRecursively(
    List<Topic> topics,
    String currentUnitName,
    List<TopicItem> flatList,
  ) {
    for (var topic in topics) {
      flatList.add(
        TopicItem(
          unitName: currentUnitName,
          topicObject: topic,
          estimatedTime: topic.estimatedTime,
          importance: topic.importance,
          difficulty: topic.difficulty,
        ),
      );
      if (topic.subtopics.isNotEmpty) {
        _addTopicsRecursively(topic.subtopics, currentUnitName, flatList);
      }
    }
  }
}

class TopicItem {
  final String unitName;
  final Topic topicObject;
  int estimatedTime;
  final int importance;
  final int difficulty;
  final int calculatedValue;

  TopicItem({
    required this.unitName,
    required this.topicObject,
    required this.estimatedTime,
    required this.importance,
    required this.difficulty,
  }) : calculatedValue = (importance * difficulty) + importance + difficulty;
}
