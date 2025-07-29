// lib/utils/study_plan_generator.dart
import 'dart:math';
import '../models/syllabus_analyzer_models.dart';
import '../models/study_plan_models.dart';

class StudyPlanGenerator {
  // Method to generate the study plan using a knapsack-like algorithm
  static StudyPlan generatePlan({
    required SyllabusAnalysisResponse syllabus,
    required String planTitle,
    required int totalAllocatedTimeMinutes, // Total time for Knapsack
    required DateTime deadline,
    required int minutesPerDay, // Minutes user can study per day
  }) {
    print('DEBUG: --- Study Plan Generation Started ---');
    print('DEBUG: Plan Title: $planTitle');
    print(
      'DEBUG: Total Allocated Time (Knapsack Capacity): $totalAllocatedTimeMinutes minutes',
    );
    print('DEBUG: Minutes Per Day (for distribution): $minutesPerDay minutes');
    print('DEBUG: Deadline: $deadline');
    print(
      'DEBUG: Syllabus Total Estimated Time: ${syllabus.totalEstimatedTimeForSyllabus} minutes',
    );

    List<TopicItem> allTopicItems = _flattenSyllabusToTopicItems(syllabus);

    // Filter out topics with 0 estimated time, as they can't be "studied" for a duration
    // This is important because the knapsack algorithm expects positive weights.
    allTopicItems = allTopicItems
        .where((item) => item.estimatedTime > 0)
        .toList();

    print(
      'DEBUG: Flattened Topic Items (with >0 estimatedTime): ${allTopicItems.length}',
    );
    for (var item in allTopicItems) {
      print(
        'DEBUG:   - Topic: ${item.topicObject.topic}, Time: ${item.estimatedTime}, Imp: ${item.importance}, Diff: ${item.difficulty}, Value: ${item.calculatedValue}',
      );
    }

    // If no valid topic items remain after filtering, return an empty plan early
    if (allTopicItems.isEmpty) {
      print(
        'DEBUG: No valid topic items with estimated time > 0 to generate plan.',
      );
      return StudyPlan(
        planTitle: planTitle,
        totalAllocatedTimeMinutes: totalAllocatedTimeMinutes,
        deadline: deadline,
        sessions: [],
      );
    }

    // Implement a dynamic programming approach for 0/1 Knapsack
    // dp[w] will store the maximum value for a weight capacity of 'w'
    List<int> dp = List.filled(totalAllocatedTimeMinutes + 1, 0);
    // `keep` table to reconstruct the items chosen
    List<List<bool>> keep = List.generate(
      allTopicItems.length + 1,
      (index) => List.filled(totalAllocatedTimeMinutes + 1, false),
    );

    // Populate the DP table
    for (int i = 1; i <= allTopicItems.length; i++) {
      TopicItem currentItem = allTopicItems[i - 1];
      int weight = currentItem.estimatedTime;
      int value = currentItem.calculatedValue;

      for (int w = 1; w <= totalAllocatedTimeMinutes; w++) {
        // Option 1: Don't include the current item
        dp[w] = dp[w]; // Inherit value from previous item set
        keep[i][w] = false; // Mark as not included

        // Option 2: Include the current item if it fits and improves value
        if (weight <= w) {
          if (value + dp[w - weight] > dp[w]) {
            dp[w] = value + dp[w - weight];
            keep[i][w] = true; // Mark as included
          }
        }
      }
    }

    // Reconstruct the selected items based on the 'keep' table
    List<TopicItem> selectedTopicItems = [];
    int currentWeight = totalAllocatedTimeMinutes;
    for (int i = allTopicItems.length; i > 0 && currentWeight >= 0; i--) {
      // Changed currentWeight > 0 to currentWeight >= 0
      // If the current item was chosen at this capacity, add it and reduce capacity
      if (keep[i][currentWeight]) {
        TopicItem selectedItem = allTopicItems[i - 1];
        selectedTopicItems.add(selectedItem);
        currentWeight -= selectedItem.estimatedTime;
      }
    }
    // Reverse the list to get them in their original syllabus order (or close to it)
    selectedTopicItems = selectedTopicItems.reversed.toList();

    print('DEBUG: Knapsack Selected Topics: ${selectedTopicItems.length}');
    for (var item in selectedTopicItems) {
      print(
        'DEBUG:   - Selected: ${item.topicObject.topic}, Time: ${item.estimatedTime}, Value: ${item.calculatedValue}',
      );
    }

    // Distribute selected topics across days based on minutesPerDay
    List<StudySession> sessions = [];
    // Start scheduling from tomorrow or today if current time is very early.
    // For simplicity, let's start from today at the beginning of the day.
    DateTime currentDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    int currentDayMinutesLeft = minutesPerDay;

    // Check if the deadline is in the past or today, adjust if needed to ensure at least one day
    int daysBetween = deadline.difference(currentDate).inDays;
    if (daysBetween < 0) {
      // Deadline is in the past
      print(
        'DEBUG: Deadline is in the past. Adjusting current date to deadline.',
      );
      currentDate = DateTime(deadline.year, deadline.month, deadline.day);
      if (currentDate.isBefore(DateTime.now())) {
        // If deadline itself is past, set it to tomorrow
        currentDate = DateTime.now().add(const Duration(days: 1));
      }
    } else if (daysBetween == 0) {
      // Deadline is today
      // If current time is past working hours, consider starting tomorrow
      if (DateTime.now().hour >= 18) {
        // Arbitrary "end of day" hour
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    for (int i = 0; i < selectedTopicItems.length; i++) {
      TopicItem item = selectedTopicItems[i];
      int remainingTopicTime = item.estimatedTime;

      while (remainingTopicTime > 0) {
        // If current day has no more time, move to the next day
        if (currentDayMinutesLeft <= 0) {
          currentDate = currentDate.add(const Duration(days: 1));
          currentDayMinutesLeft = minutesPerDay; // Reset daily capacity
          // If we pass the deadline, break
          if (currentDate.isAfter(deadline.add(const Duration(days: 1)))) {
            print(
              'DEBUG: Reached or passed deadline while scheduling. Breaking.',
            );
            break;
          }
        }

        int timeToAllocate = min(remainingTopicTime, currentDayMinutesLeft);

        sessions.add(
          StudySession(
            unitName: item.unitName,
            topic: item.topicObject,
            allocatedTimeMinutes: timeToAllocate,
            scheduledDate: currentDate,
          ),
        );
        remainingTopicTime -= timeToAllocate;
        currentDayMinutesLeft -= timeToAllocate;
      }
      if (currentDate.isAfter(deadline.add(const Duration(days: 1)))) {
        break; // Stop scheduling if we've gone past the deadline
      }
    }

    // Filter out sessions scheduled after deadline (if any large topics pushed it too far)
    sessions = sessions
        .where(
          (session) => session.scheduledDate!.isBefore(
            deadline.add(const Duration(days: 1)),
          ),
        )
        .toList();

    // Sort sessions by date and then by importance (descending)
    sessions.sort((a, b) {
      int dateCompare = a.scheduledDate!.compareTo(b.scheduledDate!);
      if (dateCompare != 0) return dateCompare;
      return b.topic.importance.compareTo(
        a.topic.importance,
      ); // Higher importance first
    });

    print('DEBUG: Generated Study Plan with ${sessions.length} sessions.');
    print('DEBUG: --- Study Plan Generation Finished ---');

    return StudyPlan(
      planTitle: planTitle,
      totalAllocatedTimeMinutes: totalAllocatedTimeMinutes,
      deadline: deadline,
      sessions: sessions,
    );
  }

  // Helper to flatten syllabus hierarchy into a list of individual TopicItems
  static List<TopicItem> _flattenSyllabusToTopicItems(
    SyllabusAnalysisResponse syllabus,
  ) {
    List<TopicItem> flatList = [];
    // syllabus.units is guaranteed non-null due to defaultValue: [] in model
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
    // topics is guaranteed non-null due to defaultValue: [] in model
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
      // topic.subtopics is guaranteed non-null due to defaultValue: [] in model
      if (topic.subtopics.isNotEmpty) {
        _addTopicsRecursively(topic.subtopics, currentUnitName, flatList);
      }
    }
  }
}

// Internal helper class to represent a topic with its calculated value for Knapsack
class TopicItem {
  final String unitName;
  final Topic topicObject;
  int estimatedTime; // Changed to mutable for internal splitting logic
  final int importance;
  final int difficulty;
  final int calculatedValue; // Value for Knapsack

  TopicItem({
    required this.unitName,
    required this.topicObject,
    required this.estimatedTime,
    required this.importance,
    required this.difficulty,
  }) : calculatedValue =
           (importance * difficulty) +
           importance +
           difficulty; // Heuristic for value, more value for higher importance/difficulty
}
