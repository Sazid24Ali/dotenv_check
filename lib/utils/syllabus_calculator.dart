// lib/utils/syllabus_calculator.dart
import '../models/syllabus_analyzer_models.dart';

class SyllabusCalculator {
  // Call this method after deserializing SyllabusAnalysisResponse
  // or after any edit that changes estimated times.
  static void calculateAllTotals(SyllabusAnalysisResponse syllabus) {
    int totalSyllabusTime = 0;
    // null check for syllabus.units is already handled by defaultValue in model,
    // but defensive coding for unexpected scenarios is fine.
    // However, for consistency with how List<T> is typically handled when using defaultValue: []
    // we can assume `units` is never null here.
    for (var unit in syllabus.units) {
      unit.totalEstimatedTime = _calculateUnitTotal(unit);
      totalSyllabusTime += unit.totalEstimatedTime;
    }
    syllabus.totalEstimatedTimeForSyllabus = totalSyllabusTime;
  }

  // Recursive helper for unit totals
  static int _calculateUnitTotal(Unit unit) {
    int unitTotal = 0;
    // Similar to above, `topics` is assumed non-null due to defaultValue: []
    for (var topic in unit.topics) {
      unitTotal += _calculateTopicTotal(topic);
    }
    return unitTotal;
  }

  // Recursive helper for topic/subtopic totals
  static int _calculateTopicTotal(Topic topic) {
    int topicTotal = topic.estimatedTime;
    // Similar to above, `subtopics` is assumed non-null due to defaultValue: []
    for (var subtopic in topic.subtopics) {
      topicTotal += _calculateTopicTotal(subtopic);
    }
    return topicTotal;
  }
}