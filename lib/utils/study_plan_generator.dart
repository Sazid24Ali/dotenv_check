// lib/utils/study_plan_generator.dart
import 'dart:math';
import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/study_plan_models.dart';
import '../models/syllabus_analyzer_models.dart';

class StudyPlanGenerator {
  static String _createUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(9999).toString();
  }

  static StudyPlan generatePlan({
    required SyllabusAnalysisResponse syllabus,
    required String planTitle,
    required int totalAllocatedTimeMinutesUserCommitment,
    required DateTime deadline,
    required int minutesPerDayForTopics,
    required int revisionMinutesPerDay,
    required TimeOfDay dailyStudyStartTime,
    required int breakMinutes,
  }) {
    final List<StudySession> sessions = [];
    final List<Topic> allTopics = [];

    for (var unit in syllabus.units) {
      void flattenTopics(List<Topic> topicList) {
        for (var topic in topicList) {
          if (topic.subtopics.isEmpty) {
            allTopics.add(topic);
          } else {
            flattenTopics(topic.subtopics);
          }
        }
      }

      flattenTopics(unit.topics);
    }

    final List<Topic> coveredTopics = [];
    final List<Topic> uncoveredTopics = [];
    int daysAvailable = deadline.difference(DateTime.now()).inDays + 1;
    if (daysAvailable <= 0) daysAvailable = 1;

    int totalMinutesAvailableForTopics = minutesPerDayForTopics * daysAvailable;

    int minutesUsed = 0;
    for (var topic in allTopics) {
      if (minutesUsed + topic.estimatedTime <= totalMinutesAvailableForTopics) {
        coveredTopics.add(topic);
        minutesUsed += topic.estimatedTime;
      } else {
        uncoveredTopics.add(topic);
      }
    }

    DateTime currentDate = DateTime.now().hour >= 20
        ? DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ).add(const Duration(days: 1))
        : DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );

    final timeFormatter = DateFormat('HH:mm');

    int topicsIndex = 0;
    while (currentDate.isBefore(deadline.add(const Duration(days: 1))) &&
        topicsIndex < coveredTopics.length) {
      DateTime sessionStartTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        dailyStudyStartTime.hour,
        dailyStudyStartTime.minute,
      );
      double dailyMinutesUsed = 0;

      while (dailyMinutesUsed < minutesPerDayForTopics &&
          topicsIndex < coveredTopics.length) {
        final topic = coveredTopics[topicsIndex];

        sessions.add(
          StudySession(
            id: _createUniqueId(),
            unitName: "Study",
            topic: topic,
            allocatedTimeMinutes: topic.estimatedTime,
            scheduledDate: currentDate,
            scheduledStartTime: timeFormatter.format(sessionStartTime),
          ),
        );
        sessionStartTime = sessionStartTime.add(
          Duration(minutes: topic.estimatedTime),
        );
        dailyMinutesUsed += topic.estimatedTime;

        if (dailyMinutesUsed < minutesPerDayForTopics &&
            topicsIndex < coveredTopics.length - 1) {
          sessions.add(
            StudySession(
              id: _createUniqueId(),
              unitName: "Break",
              isBreak: true,
              allocatedTimeMinutes: breakMinutes,
              scheduledDate: currentDate,
              scheduledStartTime: timeFormatter.format(sessionStartTime),
            ),
          );
          sessionStartTime = sessionStartTime.add(
            Duration(minutes: breakMinutes),
          );
        }
        topicsIndex++;
      }

      if (revisionMinutesPerDay > 0 && dailyMinutesUsed > 0) {
        sessions.add(
          StudySession(
            id: _createUniqueId(),
            unitName: "Revision",
            isRevision: true,
            allocatedTimeMinutes: revisionMinutesPerDay,
            scheduledDate: currentDate,
            scheduledStartTime: timeFormatter.format(sessionStartTime),
          ),
        );
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return StudyPlan(
      planTitle: planTitle,
      totalAllocatedTimeMinutesUserCommitment:
          totalAllocatedTimeMinutesUserCommitment,
      deadline: deadline,
      sessions: sessions,
      totalRevisionTimeMinutes: revisionMinutesPerDay * daysAvailable,
      uncoveredTopics: uncoveredTopics,
    );
  }

  static Future<void> scheduleDailyAlarms(
    StudyPlan plan,
    TimeOfDay alarmTime,
  ) async {
    if (plan.sessions.isEmpty) return;
    final random = Random();

    for (var session in plan.sessions) {
      if (session.topic != null && !session.isBreak && !session.isRevision) {
        final alarmDateTime = DateTime(
          session.scheduledDate!.year,
          session.scheduledDate!.month,
          session.scheduledDate!.day,
          alarmTime.hour,
          alarmTime.minute,
        );

        if (alarmDateTime.isBefore(DateTime.now())) continue;

        final alarmSettings = AlarmSettings(
          id: random.nextInt(99999) + 1,
          dateTime: alarmDateTime,
          assetAudioPath: 'assets/sounds/alarm.mp3',
          loopAudio: true,
          vibrate: true,
          androidFullScreenIntent: true,
          volumeSettings: VolumeSettings.fade(
            volume: 0.8,
            fadeDuration: const Duration(seconds: 3),
          ),
          notificationSettings: NotificationSettings(
            title: 'Time to study: ${session.topic!.topic}',
            body: 'Your scheduled session is starting now.',
          ),
        );
        await Alarm.set(alarmSettings: alarmSettings);
      }
    }
  }
}
