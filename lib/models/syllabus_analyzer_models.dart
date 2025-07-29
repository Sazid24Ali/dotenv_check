// lib/models/syllabus_analyzer_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'syllabus_analyzer_models.g.dart';

@JsonSerializable(explicitToJson: true)
class SyllabusAnalysisResponse {
  @JsonKey(name: 'is_syllabus')
  final bool isSyllabus;
  @JsonKey(name: 'total_estimated_time_for_syllabus', defaultValue: 0)
  int totalEstimatedTimeForSyllabus;

  @JsonKey(name: 'course_title', defaultValue: "")
  final String courseTitle;

  @JsonKey(name: 'course_code', defaultValue: "")
  final String courseCode;

  @JsonKey(defaultValue: "")
  final String instructor;

  @JsonKey(defaultValue: "")
  final String semester;

  final int? year;

  @JsonKey(name: 'learning_objectives', defaultValue: [])
  final List<String> learningObjectives;

  @JsonKey(name: 'grading_breakdown', defaultValue: {})
  final Map<String, String> gradingBreakdown;

  @JsonKey(name: 'required_materials', defaultValue: [])
  final List<String> requiredMaterials;

  @JsonKey(name: 'important_dates', defaultValue: [])
  final List<ImportantDateEntry> importantDates;

  @JsonKey(name: 'contact_information')
  final ContactInformation? contactInformation;

  @JsonKey(name: 'notes_or_disclaimers', defaultValue: "")
  final String notesOrDisclaimers;

  // weekly_schedule is a list of Units, which are currently mapped from "topic" in Gemini's JSON
  @JsonKey(name: 'weekly_schedule', defaultValue: [])
  final List<Unit> units;

  SyllabusAnalysisResponse({
    required this.isSyllabus,
    this.totalEstimatedTimeForSyllabus = 0,
    this.courseTitle = "",
    this.courseCode = "",
    this.instructor = "",
    this.semester = "",
    this.year,
    this.learningObjectives = const [],
    this.gradingBreakdown = const {},
    this.requiredMaterials = const [],
    this.importantDates = const [],
    this.contactInformation,
    this.notesOrDisclaimers = "",
    required this.units,
  });

  factory SyllabusAnalysisResponse.fromJson(Map<String, dynamic> json) =>
      _$SyllabusAnalysisResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SyllabusAnalysisResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Unit {
  // CHANGE HERE: Map 'topic' from Gemini's JSON to 'unitName' in your model
  @JsonKey(name: 'topic', defaultValue: "")
  String unitName;

  // Add week_number from Gemini's JSON if you want to store it in Unit
  @JsonKey(name: 'week_number')
  final int? weekNumber; // It's in Gemini's JSON, can be added here if needed

  @JsonKey(name: 'total_estimated_time', defaultValue: 0)
  int totalEstimatedTime;

  // The 'topics' here should map to 'subtopics' in Gemini's JSON for this level
  // This requires a bit of a re-thinking of the model or prompt.
  // For now, let's keep it as 'topics' and address the mapping issue.

  // Re-evaluating the prompt:
  // Gemini's output for "weekly_schedule" has "topic", "estimated_time", "subtopics".
  // Your Dart model has:
  // SyllabusAnalysisResponse.units (List<Unit>)
  // Unit.unitName
  // Unit.topics (List<Topic>)

  // The direct mapping would be:
  // weekly_schedule (list) -> units (list)
  //   item in weekly_schedule ("topic": "Unit I", "subtopics": [...]) -> Unit object
  //     "topic" (string) -> Unit.unitName (string)
  //     "subtopics" (list) -> Unit.topics (list)

  // So, the `Unit` class's `topics` field needs to read from `subtopics` if it's acting as a "container" for the next level.
  // This implies the structure of your `weekly_schedule` in the prompt is slightly different from your model's expectation.

  // Let's adjust based on the Gemini's output structure you provided:
  // Gemini gives: { "topic": "Unit I", "subtopics": [ { "topic": "Intro to AI", "subtopics": [...] } ] }
  // Your model has: Unit { unitName, topics } where topics is List<Topic>

  // Therefore, the topics field in Unit should map to 'subtopics' from Gemini's output for this level.
  @JsonKey(name: 'subtopics', defaultValue: [])
  final List<Topic> topics;

  Unit({
    required this.unitName,
    this.weekNumber, // Make it optional in constructor if nullable
    this.totalEstimatedTime = 0,
    required this.topics,
  });

  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);
  Map<String, dynamic> toJson() => _$UnitToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Topic {
  @JsonKey(defaultValue: "")
  String topic;
  @JsonKey(name: 'estimated_time', defaultValue: 0)
  int estimatedTime;
  @JsonKey(defaultValue: 3)
  int importance;
  @JsonKey(defaultValue: 3)
  int difficulty;

  @JsonKey(defaultValue: [])
  final List<String> resources;

  // Subtopics of a Topic should also be read from 'subtopics' in Gemini's JSON
  @JsonKey(name: 'subtopics', defaultValue: [])
  final List<Topic> subtopics; // Recursive nesting

  @JsonKey(name: 'time_reasoning', defaultValue: "")
  final String timeReasoning;

  Topic({
    required this.topic,
    this.estimatedTime = 0,
    this.importance = 3,
    this.difficulty = 3,
    this.resources = const [],
    this.subtopics = const [],
    this.timeReasoning = "",
  });

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
  Map<String, dynamic> toJson() => _$TopicToJson(this);
}

@JsonSerializable()
class ImportantDateEntry {
  @JsonKey(defaultValue: "")
  final String event;
  @JsonKey(defaultValue: "")
  final String date;

  ImportantDateEntry({this.event = "", this.date = ""});

  factory ImportantDateEntry.fromJson(Map<String, dynamic> json) =>
      _$ImportantDateEntryFromJson(json);
  Map<String, dynamic> toJson() => _$ImportantDateEntryToJson(this);
}

@JsonSerializable()
class ContactInformation {
  @JsonKey(defaultValue: "")
  final String email;
  @JsonKey(name: 'office_hours', defaultValue: "")
  final String officeHours;
  @JsonKey(name: 'other_details', defaultValue: "")
  final String otherDetails;

  ContactInformation({
    this.email = "",
    this.officeHours = "",
    this.otherDetails = "",
  });

  factory ContactInformation.fromJson(Map<String, dynamic> json) =>
      _$ContactInformationFromJson(json);
  Map<String, dynamic> toJson() => _$ContactInformationToJson(this);
}
