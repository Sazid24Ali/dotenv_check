// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'syllabus_analyzer_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyllabusAnalysisResponse _$SyllabusAnalysisResponseFromJson(
  Map<String, dynamic> json,
) => SyllabusAnalysisResponse(
  isSyllabus: json['is_syllabus'] as bool,
  totalEstimatedTimeForSyllabus:
      (json['total_estimated_time_for_syllabus'] as num?)?.toInt() ?? 0,
  courseTitle: json['course_title'] as String? ?? '',
  courseCode: json['course_code'] as String? ?? '',
  instructor: json['instructor'] as String? ?? '',
  semester: json['semester'] as String? ?? '',
  year: (json['year'] as num?)?.toInt(),
  learningObjectives:
      (json['learning_objectives'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  gradingBreakdown:
      (json['grading_breakdown'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      {},
  requiredMaterials:
      (json['required_materials'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  importantDates:
      (json['important_dates'] as List<dynamic>?)
          ?.map((e) => ImportantDateEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  contactInformation: json['contact_information'] == null
      ? null
      : ContactInformation.fromJson(
          json['contact_information'] as Map<String, dynamic>,
        ),
  notesOrDisclaimers: json['notes_or_disclaimers'] as String? ?? '',
  units:
      (json['weekly_schedule'] as List<dynamic>?)
          ?.map((e) => Unit.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$SyllabusAnalysisResponseToJson(
  SyllabusAnalysisResponse instance,
) => <String, dynamic>{
  'is_syllabus': instance.isSyllabus,
  'total_estimated_time_for_syllabus': instance.totalEstimatedTimeForSyllabus,
  'course_title': instance.courseTitle,
  'course_code': instance.courseCode,
  'instructor': instance.instructor,
  'semester': instance.semester,
  'year': instance.year,
  'learning_objectives': instance.learningObjectives,
  'grading_breakdown': instance.gradingBreakdown,
  'required_materials': instance.requiredMaterials,
  'important_dates': instance.importantDates.map((e) => e.toJson()).toList(),
  'contact_information': instance.contactInformation?.toJson(),
  'notes_or_disclaimers': instance.notesOrDisclaimers,
  'weekly_schedule': instance.units.map((e) => e.toJson()).toList(),
};

Unit _$UnitFromJson(Map<String, dynamic> json) => Unit(
  unitName: json['unit_name'] as String? ?? '',
  totalEstimatedTime: (json['total_estimated_time'] as num?)?.toInt() ?? 0,
  topics:
      (json['topics'] as List<dynamic>?)
          ?.map((e) => Topic.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$UnitToJson(Unit instance) => <String, dynamic>{
  'unit_name': instance.unitName,
  'total_estimated_time': instance.totalEstimatedTime,
  'topics': instance.topics.map((e) => e.toJson()).toList(),
};

Topic _$TopicFromJson(Map<String, dynamic> json) => Topic(
  topic: json['topic'] as String? ?? '',
  estimatedTime: (json['estimated_time'] as num?)?.toInt() ?? 0,
  importance: (json['importance'] as num?)?.toInt() ?? 3,
  difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
  resources:
      (json['resources'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  subtopics:
      (json['subtopics'] as List<dynamic>?)
          ?.map((e) => Topic.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  timeReasoning: json['time_reasoning'] as String? ?? '',
);

Map<String, dynamic> _$TopicToJson(Topic instance) => <String, dynamic>{
  'topic': instance.topic,
  'estimated_time': instance.estimatedTime,
  'importance': instance.importance,
  'difficulty': instance.difficulty,
  'resources': instance.resources,
  'subtopics': instance.subtopics.map((e) => e.toJson()).toList(),
  'time_reasoning': instance.timeReasoning,
};

ImportantDateEntry _$ImportantDateEntryFromJson(Map<String, dynamic> json) =>
    ImportantDateEntry(
      event: json['event'] as String? ?? '',
      date: json['date'] as String? ?? '',
    );

Map<String, dynamic> _$ImportantDateEntryToJson(ImportantDateEntry instance) =>
    <String, dynamic>{'event': instance.event, 'date': instance.date};

ContactInformation _$ContactInformationFromJson(Map<String, dynamic> json) =>
    ContactInformation(
      email: json['email'] as String? ?? '',
      officeHours: json['office_hours'] as String? ?? '',
      otherDetails: json['other_details'] as String? ?? '',
    );

Map<String, dynamic> _$ContactInformationToJson(ContactInformation instance) =>
    <String, dynamic>{
      'email': instance.email,
      'office_hours': instance.officeHours,
      'other_details': instance.otherDetails,
    };
