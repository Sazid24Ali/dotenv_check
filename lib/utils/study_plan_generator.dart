// lib/utils/study_plan_generator.dart
import 'dart:math';
import '../models/syllabus_analyzer_models.dart';
import '../models/study_plan_models.dart';
import 'package:flutter/material.dart'; // Import for TimeOfDay

class StudyPlanGenerator {
  static StudyPlan generatePlan({
    required String planTitle,
    required int totalAllocatedTimeMinutesUserCommitment,
    required DateTime deadline,
    required int minutesPerDayForTopics,
    required int revisionMinutesPerDay,
    required TimeOfDay dailyStudyStartTime,
    required int breakMinutes, // Break minutes after each session
    required SyllabusAnalysisResponse syllabus,
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
    print('DEBUG: Break Minutes After Session: $breakMinutes minutes');
    print('DEBUG: Deadline: $deadline');
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
            // Create new TopicItem instances for mutable estimatedTime
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

    if (DateTime.now().hour >= 20) {
      currentDate = currentDate.add(const Duration(days: 1));
    }

    int topicIndex = 0;

    while (currentDate.isBefore(deadline.add(const Duration(days: 1)))) {
      print(
        'DEBUG: Scheduling for date: ${currentDate.toLocal().toIso8601String().substring(0, 10)}',
      );

      int dailyMinutesRemainingBudget =
          minutesPerDayForTopics +
          revisionMinutesPerDay; // Total study time budget for the day
      int dailyStudyMinutesScheduled =
          0; // Tracks actual study minutes scheduled (topics + revision)

      DateTime currentSessionStartTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        dailyStudyStartTime.hour,
        dailyStudyStartTime.minute,
      );

      // --- 1. Schedule all Topics for the Day First ---
      int currentDayTopicMinutesScheduled = 0;
      while (minutesPerDayForTopics > currentDayTopicMinutesScheduled &&
          topicIndex < topicsToSchedule.length) {
        TopicItem currentTopicItem = topicsToSchedule[topicIndex];
        int timeToAllocateToTopic = min(
          currentTopicItem.estimatedTime,
          minutesPerDayForTopics - currentDayTopicMinutesScheduled,
        );

        // Check if this topic + potential break fits the remaining total daily budget for *study*
        // A break will be inserted BEFORE this session if it's not the very first session of the day
        int totalBlockTimeIncludingBreak = timeToAllocateToTopic;
        if (currentDayTopicMinutesScheduled > 0 &&
            breakMinutes > 0 &&
            (dailyStudyMinutesScheduled +
                    timeToAllocateToTopic +
                    breakMinutes) <=
                dailyMinutesRemainingBudget) {
          // If there's an existing session on this day, add a break BEFORE the next study session
          sessions.add(
            StudySession(
              unitName: 'Break',
              topic: null,
              allocatedTimeMinutes: breakMinutes,
              scheduledDate: currentDate,
              isRevision: false,
              isBreak: true,
              scheduledStartTime: currentSessionStartTime
                  .toLocal()
                  .toString()
                  .substring(11, 16),
            ),
          );
          currentSessionStartTime = currentSessionStartTime.add(
            Duration(minutes: breakMinutes),
          );
          print(
            'DEBUG:   Added $breakMinutes min break before topic session.',
          );
        }

        if (timeToAllocateToTopic > 0 &&
            (dailyStudyMinutesScheduled + timeToAllocateToTopic) <=
                dailyMinutesRemainingBudget) {
          sessions.add(
            StudySession(
              unitName: currentTopicItem.unitName,
              topic: currentTopicItem.topicObject,
              allocatedTimeMinutes: timeToAllocateToTopic,
              scheduledDate: currentDate,
              isRevision: false,
              isBreak: false,
              scheduledStartTime: currentSessionStartTime
                  .toLocal()
                  .toString()
                  .substring(11, 16),
            ),
          );
          currentTopicItem.estimatedTime -= timeToAllocateToTopic;
          currentDayTopicMinutesScheduled +=
              timeToAllocateToTopic; // Track topics used this day
          dailyStudyMinutesScheduled +=
              timeToAllocateToTopic; // Track total study used this day
          currentSessionStartTime = currentSessionStartTime.add(
            Duration(minutes: timeToAllocateToTopic),
          );

          if (currentTopicItem.estimatedTime <= 0) {
            topicIndex++;
          }
        } else {
          break; // Topic doesn't fit in remaining topic budget for the day
        }
      }

      // --- 2. Schedule Revision for the Day (After all topics for the day are scheduled) ---
      // FIX: Stricter condition for scheduling revision
      if (revisionMinutesPerDay > 0) {
        bool topicsAllCoveredGlobally = topicIndex >= topicsToSchedule.length;
        bool topicsScheduledToday = currentDayTopicMinutesScheduled > 0;

        // Only add revision if topics were scheduled today, OR all topics are covered globally,
        // OR if the user's topic budget for the day is 0 (meaning they only allocated for revision)
        if (topicsScheduledToday ||
            topicsAllCoveredGlobally ||
            minutesPerDayForTopics == 0) {
          // Add break before revision if there were previous study blocks today (topic or break)
          // AND breakMinutes > 0 AND it fits in the remaining daily budget
          if (currentDayTopicMinutesScheduled > 0 &&
              breakMinutes > 0 &&
              (dailyStudyMinutesScheduled +
                      revisionMinutesPerDay +
                      breakMinutes) <=
                  dailyMinutesRemainingBudget) {
            sessions.add(
              StudySession(
                unitName: 'Break',
                topic: null,
                allocatedTimeMinutes: breakMinutes,
                scheduledDate: currentDate,
                isRevision: false,
                isBreak: true,
                scheduledStartTime: currentSessionStartTime
                    .toLocal()
                    .toString()
                    .substring(11, 16),
              ),
            );
            currentSessionStartTime = currentSessionStartTime.add(
              Duration(minutes: breakMinutes),
            );
            print(
              'DEBUG:   Added $breakMinutes min break before revision session.',
            );
          }

          // Check if revision fits within the total daily study budget
          if ((dailyStudyMinutesScheduled + revisionMinutesPerDay) <=
              dailyMinutesRemainingBudget) {
            sessions.add(
              StudySession(
                unitName: 'General Revision',
                topic: null,
                allocatedTimeMinutes: revisionMinutesPerDay,
                scheduledDate: currentDate,
                isRevision: true,
                isBreak: false,
                scheduledStartTime: currentSessionStartTime
                    .toLocal()
                    .toString()
                    .substring(11, 16),
              ),
            );
            dailyStudyMinutesScheduled += revisionMinutesPerDay;
            currentSessionStartTime = currentSessionStartTime.add(
              Duration(minutes: revisionMinutesPerDay),
            );
          }
        }
      }

      // This condition handles a very rare edge case: if total daily budget is 0 for all types, but topics are not exhausted.
      // It ensures the date still advances to avoid an infinite loop.
      // Also checks if nothing was scheduled today but there's potential study.
      if (dailyStudyMinutesScheduled == 0 &&
          topicIndex < topicsToSchedule.length &&
          (minutesPerDayForTopics + revisionMinutesPerDay + breakMinutes ==
              0)) {
        print(
          'DEBUG: Daily budget is 0, but topics remain. Advancing date without scheduling anything.',
        );
      } else if (dailyStudyMinutesScheduled == 0 &&
          (minutesPerDayForTopics > 0 ||
              revisionMinutesPerDay > 0 ||
              breakMinutes > 0) &&
          topicIndex < topicsToSchedule.length) {
        print(
          'DEBUG: No study scheduled today despite budget & topics. This implies blocks are too small or daily time is exhausted. Advancing date.',
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
    final int calculatedTotalBreakTimeMinutes = finalSessions
        .where((s) => s.isBreak)
        .fold(0, (sum, s) => sum + s.allocatedTimeMinutes);

    // FIX: Removed sorting by scheduledStartTime from generator. This should be handled by user reordering.
    // However, for initial display consistency, we might still want a basic sort.
    // If the goal is strict sequential from input, only sorting by date should be required.
    // The previous sort would be good for displaying sessions in order on display screen.
    // So let's keep a stable sort by time within day for generator's output.
    finalSessions.sort((a, b) {
      int dateCompare = a.scheduledDate!.compareTo(b.scheduledDate!);
      if (dateCompare != 0) return dateCompare;

      // On the same day: Sort by scheduled start time to maintain daily sequence
      if (a.scheduledStartTime != null && b.scheduledStartTime != null) {
        return a.scheduledStartTime!.compareTo(b.scheduledStartTime!);
      }
      // If start times are identical (unlikely with accurate scheduling), use tie-breakers
      // Breaks come after actual study/revision if start times are identical
      if (!a.isBreak && b.isBreak) return -1;
      if (a.isBreak && !b.isBreak) return 1;

      // Non-revision sessions before revision if start times are identical
      if (!a.isRevision && b.isRevision) return -1;
      if (a.isRevision && !b.isRevision) return 1;

      return 0; // Maintain current order for other cases
    });

    print(
      'DEBUG: Generated Study Plan with ${finalSessions.length} sessions (including revision & breaks).',
    );
    print(
      'DEBUG: User Committed Total Time (up to deadline): $totalAllocatedTimeMinutesUserCommitment minutes',
    );
    print(
      'DEBUG: Total Scheduled Study Time in Plan (Topics + Revision): ${totalScheduledMinutesInPlan - calculatedTotalBreakTimeMinutes} minutes',
    );
    print(
      'DEBUG: Total Revision Time in Plan: $calculatedTotalRevisionTimeMinutes minutes',
    );
    print(
      'DEBUG: Total Break Time in Plan: $calculatedTotalBreakTimeMinutes minutes',
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
