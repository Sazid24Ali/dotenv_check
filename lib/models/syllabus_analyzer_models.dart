// lib/models/syllabus_analyzer_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'syllabus_analyzer_models.g.dart';

@JsonSerializable(explicitToJson: true)
class SyllabusAnalysisResponse {
  @JsonKey(name: 'is_syllabus')
  final bool isSyllabus;
  // ADDED defaultValue for total_estimated_time_for_syllabus
  @JsonKey(name: 'total_estimated_time_for_syllabus', defaultValue: 0)
  int totalEstimatedTimeForSyllabus;

  @JsonKey(name: 'course_title', defaultValue: "") // ADDED defaultValue
  final String courseTitle; // Changed to non-nullable

  @JsonKey(name: 'course_code', defaultValue: "") // ADDED defaultValue
  final String courseCode; // Changed to non-nullable

  @JsonKey(defaultValue: "") // ADDED defaultValue
  final String instructor; // Changed to non-nullable

  @JsonKey(defaultValue: "") // ADDED defaultValue
  final String semester; // Changed to non-nullable

  final int? year; // Can still be null if not found

  @JsonKey(name: 'learning_objectives', defaultValue: const [])
  final List<String> learningObjectives;

  @JsonKey(name: 'grading_breakdown', defaultValue: const {})
  final Map<String, String> gradingBreakdown;

  @JsonKey(name: 'required_materials', defaultValue: const [])
  final List<String> requiredMaterials;

  @JsonKey(name: 'important_dates', defaultValue: const [])
  final List<ImportantDateEntry> importantDates;

  @JsonKey(name: 'contact_information') // Keep nullable for nested object
  final ContactInformation? contactInformation;

  @JsonKey(name: 'notes_or_disclaimers', defaultValue: "") // ADDED defaultValue
  final String notesOrDisclaimers; // Changed to non-nullable

  @JsonKey(name: 'weekly_schedule', defaultValue: const [])
  final List<Unit> units;

  SyllabusAnalysisResponse({
    required this.isSyllabus,
    // Initialize with a non-null default
    this.totalEstimatedTimeForSyllabus = 0,
    this.courseTitle = "", // Set default in constructor too
    this.courseCode = "", // Set default in constructor too
    this.instructor = "", // Set default in constructor too
    this.semester = "", // Set default in constructor too
    this.year, // Can still be null
    this.learningObjectives = const [],
    this.gradingBreakdown = const {},
    this.requiredMaterials = const [],
    this.importantDates = const [],
    this.contactInformation,
    this.notesOrDisclaimers = "", // Set default in constructor too
    required this.units,
  });

  factory SyllabusAnalysisResponse.fromJson(Map<String, dynamic> json) =>
      _$SyllabusAnalysisResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SyllabusAnalysisResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Unit {
  @JsonKey(name: 'unit_name', defaultValue: "") // ADDED defaultValue
  String unitName; // Changed to non-nullable
  // ADDED defaultValue for total_estimated_time
  @JsonKey(name: 'total_estimated_time', defaultValue: 0)
  int totalEstimatedTime;

  @JsonKey(defaultValue: const [])
  final List<Topic> topics;

  Unit({
    required this.unitName,
    // Initialize with a non-null default
    this.totalEstimatedTime = 0,
    required this.topics,
  });

  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);
  Map<String, dynamic> toJson() => _$UnitToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Topic {
  @JsonKey(defaultValue: "") // ADDED defaultValue
  String topic; // Changed to non-nullable
  // ADDED defaultValue for estimated_time
  @JsonKey(name: 'estimated_time', defaultValue: 0)
  int estimatedTime;
  // ADDED defaultValue for importance and difficulty
  @JsonKey(defaultValue: 3)
  int importance;
  @JsonKey(defaultValue: 3)
  int difficulty;

  @JsonKey(defaultValue: const [])
  final List<String> resources;

  @JsonKey(defaultValue: const [])
  final List<Topic> subtopics; // Recursive nesting

  @JsonKey(name: 'time_reasoning', defaultValue: "") // ADDED defaultValue
  final String timeReasoning; // Changed to non-nullable

  Topic({
    required this.topic,
    // Initialize with a non-null default
    this.estimatedTime = 0,
    this.importance = 3,
    this.difficulty = 3,
    this.resources = const [],
    this.subtopics = const [],
    this.timeReasoning = "", // Set default in constructor too
  });

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
  Map<String, dynamic> toJson() => _$TopicToJson(this);
}

@JsonSerializable()
class ImportantDateEntry {
  @JsonKey(defaultValue: "") // ADDED defaultValue
  final String event; // Changed to non-nullable
  @JsonKey(defaultValue: "") // ADDED defaultValue
  final String date; // Changed to non-nullable

  ImportantDateEntry({
    this.event = "",
    this.date = "",
  }); // Set defaults in constructor

  factory ImportantDateEntry.fromJson(Map<String, dynamic> json) =>
      _$ImportantDateEntryFromJson(json);
  Map<String, dynamic> toJson() => _$ImportantDateEntryToJson(this);
}

@JsonSerializable()
class ContactInformation {
  @JsonKey(defaultValue: "") // ADDED defaultValue
  final String email; // Changed to non-nullable
  @JsonKey(name: 'office_hours', defaultValue: "") // ADDED defaultValue
  final String officeHours; // Changed to non-nullable
  @JsonKey(name: 'other_details', defaultValue: "") // ADDED defaultValue
  final String otherDetails; // Changed to non-nullable

  ContactInformation({
    this.email = "",
    this.officeHours = "",
    this.otherDetails = "",
  }); // Set defaults in constructor

  factory ContactInformation.fromJson(Map<String, dynamic> json) =>
      _$ContactInformationFromJson(json);
  Map<String, dynamic> toJson() => _$ContactInformationToJson(this);
}