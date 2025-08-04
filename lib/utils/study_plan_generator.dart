import 'package:intl/intl.dart';
import '../models/study_plan_models.dart';
import '../models/syllabus_analyzer_models.dart';

/// A utility class to generate a structured study plan from a list of topics.
///
/// This generator takes a flat list of topics and distributes them across a
/// specified number of days, creating a detailed schedule with calculated
/// time slots for studying, breaks, and daily revision.
class StudyPlanGenerator {
  /// Generates a [StudyPlan].
  ///
  /// [topics]: The list of all [SubTopic] items to be scheduled.
  /// [totalDays]: The total number of days the plan should span.
  /// [hoursPerDay]: The number of hours available for study each day.
  /// [breakDurationMinutes]: The duration of breaks between topics.
  /// [revisionDurationMinutes]: The duration of the revision session at the end of each day.
  static StudyPlan generateStudyPlan({
    required List<SubTopic> topics,
    required int totalDays,
    required double hoursPerDay,
    int breakDurationMinutes = 10,
    int revisionDurationMinutes = 30,
  }) {
    final List<DailySchedule> dailySchedules = [];
    final DateFormat timeFormat = DateFormat('HH:mm');

    // 1. Distribute topics evenly across the total number of days for a more balanced schedule.
    final List<List<SubTopic>> dailyTopicChunks = [];
    if (topics.isNotEmpty && totalDays > 0) {
      final baseTopicsPerDay = topics.length ~/ totalDays;
      final extraTopics = topics.length % totalDays;
      int currentTopicIndex = 0;

      for (int i = 0; i < totalDays; i++) {
        // Assign one of the 'extra' topics to the current day until they are all distributed.
        int topicsForThisDayCount =
            baseTopicsPerDay + (i < extraTopics ? 1 : 0);

        if (currentTopicIndex < topics.length) {
          final endOfChunk = currentTopicIndex + topicsForThisDayCount;
          dailyTopicChunks.add(topics.sublist(currentTopicIndex,
              endOfChunk > topics.length ? topics.length : endOfChunk));
          currentTopicIndex = endOfChunk;
        } else {
          // Add an empty list if there are no more topics to assign.
          dailyTopicChunks.add([]);
        }
      }
    }

    // Ensure we have a schedule for each day, even if there are no topics left.
    while (dailyTopicChunks.length < totalDays) {
      dailyTopicChunks.add([]);
    }

    // 2. Build the detailed schedule for each day.
    for (int i = 0; i < totalDays; i++) {
      final dayNumber = i + 1;
      final topicsForThisDay = dailyTopicChunks[i];
      final List<TimeSlot> timeSlots = [];
      // Each day's schedule starts at 9:00 AM.
      DateTime dayStartTime = DateTime.now()
          .copyWith(hour: 9, minute: 0, second: 0, millisecond: 0);

      if (topicsForThisDay.isEmpty) {
        // If there are no topics for the day, mark it as a free day.
        timeSlots.add(TimeSlot(
          startTime: "All Day",
          endTime: "",
          topic: "Free Day / Catch-up",
        ));
      } else {
        // Calculate the total time available for studying topics.
        final totalMinutesInDay = (hoursPerDay * 60).round();
        final totalBreakTime = (topicsForThisDay.length > 1)
            ? (topicsForThisDay.length - 1) * breakDurationMinutes
            : 0;
        final availableTopicTime =
            totalMinutesInDay - totalBreakTime - revisionDurationMinutes;

        // Check if there is enough time to cover the topics.
        if (availableTopicTime < topicsForThisDay.length) {
          // If not enough time (less than 1 min per topic), show an error.
          timeSlots.add(TimeSlot(
            startTime: "Error",
            endTime: "",
            topic:
                "Not enough hours to cover the topics scheduled for this day.",
          ));
          dailySchedules
              .add(DailySchedule(day: dayNumber, timeSlots: timeSlots));
          continue; // Skip to the next day.
        }

        final timePerTopic =
            (availableTopicTime / topicsForThisDay.length).floor();
        DateTime currentTime = dayStartTime;

        for (int j = 0; j < topicsForThisDay.length; j++) {
          final topic = topicsForThisDay[j];
          final startTime = currentTime;
          final endTime = startTime.add(Duration(minutes: timePerTopic));

          // Add the time slot for the current topic.
          timeSlots.add(TimeSlot(
            startTime: timeFormat.format(startTime),
            endTime: timeFormat.format(endTime),
            topic: topic.name,
          ));
          currentTime = endTime;

          // Add a break after the topic, if it's not the last one.
          if (j < topicsForThisDay.length - 1) {
            final breakStartTime = currentTime;
            final breakEndTime =
                breakStartTime.add(Duration(minutes: breakDurationMinutes));
            timeSlots.add(TimeSlot(
              startTime: timeFormat.format(breakStartTime),
              endTime: timeFormat.format(breakEndTime),
              topic: "Break",
            ));
            currentTime = breakEndTime;
          }
        }

        // Add the final revision session at the end of the day.
        final revisionStartTime = currentTime;
        final revisionEndTime =
            revisionStartTime.add(Duration(minutes: revisionDurationMinutes));
        timeSlots.add(TimeSlot(
          startTime: timeFormat.format(revisionStartTime),
          endTime: timeFormat.format(revisionEndTime),
          topic: "Revision of Day's Topics",
        ));
      }

      dailySchedules.add(DailySchedule(day: dayNumber, timeSlots: timeSlots));
    }

    return StudyPlan(
        planName: "Generated Study Plan", dailySchedules: dailySchedules);
  }
}
