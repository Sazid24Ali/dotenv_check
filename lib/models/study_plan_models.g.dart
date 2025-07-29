// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_plan_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudyPlan _$StudyPlanFromJson(Map<String, dynamic> json) => StudyPlan(
  planTitle: json['planTitle'] as String,
  totalAllocatedTimeMinutes: (json['totalAllocatedTimeMinutes'] as num).toInt(),
  deadline: DateTime.parse(json['deadline'] as String),
  sessions: (json['sessions'] as List<dynamic>)
      .map((e) => StudySession.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$StudyPlanToJson(StudyPlan instance) => <String, dynamic>{
  'planTitle': instance.planTitle,
  'totalAllocatedTimeMinutes': instance.totalAllocatedTimeMinutes,
  'deadline': instance.deadline.toIso8601String(),
  'sessions': instance.sessions.map((e) => e.toJson()).toList(),
};

StudySession _$StudySessionFromJson(Map<String, dynamic> json) => StudySession(
  unitName: json['unitName'] as String,
  topic: Topic.fromJson(json['topic'] as Map<String, dynamic>),
  allocatedTimeMinutes: (json['allocatedTimeMinutes'] as num).toInt(),
  scheduledDate: json['scheduledDate'] == null
      ? null
      : DateTime.parse(json['scheduledDate'] as String),
);

Map<String, dynamic> _$StudySessionToJson(StudySession instance) =>
    <String, dynamic>{
      'unitName': instance.unitName,
      'topic': instance.topic.toJson(),
      'allocatedTimeMinutes': instance.allocatedTimeMinutes,
      'scheduledDate': instance.scheduledDate?.toIso8601String(),
    };
