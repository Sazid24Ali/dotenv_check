// lib/models/study_plan_models.dart
import 'package:json_annotation/json_annotation.dart';
import 'syllabus_analyzer_models.dart';

part 'study_plan_models.g.dart';

@JsonSerializable(explicitToJson: true)
class StudyPlan {
  final String planTitle;
  final int totalAllocatedTimeMinutesUserCommitment;
  final DateTime deadline;
  final List<StudySession> sessions;
  final int totalRevisionTimeMinutes;

  @JsonKey(defaultValue: [])
  final List<Topic> uncoveredTopics;

  StudyPlan({
    required this.planTitle,
    required this.totalAllocatedTimeMinutesUserCommitment,
    required this.deadline,
    required this.sessions,
    required this.totalRevisionTimeMinutes,
    this.uncoveredTopics = const [],
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) =>
      _$StudyPlanFromJson(json);
  Map<String, dynamic> toJson() => _$StudyPlanToJson(this);
}

@JsonSerializable(explicitToJson: true)
class StudySession {
  // Added a unique ID to make sessions reorderable and deletable.
  final String id;
  final String unitName;
  final Topic? topic;
  final int allocatedTimeMinutes;
  final DateTime? scheduledDate;
  final bool isRevision;
  final bool isBreak;
  String? scheduledStartTime;

  StudySession({
    required this.id, // ID is now required
    required this.unitName,
    this.topic,
    required this.allocatedTimeMinutes,
    this.scheduledDate,
    this.isRevision = false,
    this.isBreak = false,
    this.scheduledStartTime,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) =>
      _$StudySessionFromJson(json);
  Map<String, dynamic> toJson() => _$StudySessionToJson(this);
}
