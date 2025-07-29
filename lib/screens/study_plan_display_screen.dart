// lib/screens/study_plan_display_screen.dart
import 'package:flutter/material.dart';
import '../models/study_plan_models.dart';
// Removed unused import: import '../utils/syllabus_calculator.dart'; // For formatting time

class StudyPlanDisplayScreen extends StatelessWidget {
  final StudyPlan plan;

  const StudyPlanDisplayScreen({super.key, required this.plan});

  // Helper to format time (similar to what's in TopicEditorScreen)
  String _formatTime(int minutes) {
    if (minutes < 0) return "N/A";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return "${h}h ${m}m";
    if (h > 0) return "${h}h";
    return "${m}m";
  }

  @override
  Widget build(BuildContext context) {
    // Group sessions by date
    final Map<DateTime, List<StudySession>> sessionsByDate = {};
    for (var session in plan.sessions) {
      if (session.scheduledDate != null) {
        // Normalize date to just year-month-day to group sessions on the same day
        final normalizedDate = DateTime(
          session.scheduledDate!.year,
          session.scheduledDate!.month,
          session.scheduledDate!.day,
        );
        sessionsByDate.putIfAbsent(normalizedDate, () => []).add(session);
      }
    }

    final sortedDates = sessionsByDate.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.planTitle),
            Text(
              'Deadline: ${plan.deadline.toLocal().year}-${plan.deadline.toLocal().month.toString().padLeft(2, '0')}-${plan.deadline.toLocal().day.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ), // Smaller, lighter text for subtitle
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Allocated Study Time: ${_formatTime(plan.totalAllocatedTimeMinutes)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Topics Selected: ${plan.sessions.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            Expanded(
              child: sortedDates.isEmpty
                  ? const Center(child: Text('No study sessions scheduled.'))
                  : ListView.builder(
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        final date = sortedDates[index];
                        final sessionsForDay = sessionsByDate[date]!;
                        final totalTimeForDay = sessionsForDay.fold<int>(
                          0,
                          (sum, session) => sum + session.allocatedTimeMinutes,
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 3,
                          child: ExpansionTile(
                            title: Text(
                              // Display date without time for grouping
                              '${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-${date.toLocal().day.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              'Total for day: ${_formatTime(totalTimeForDay)}',
                            ),
                            children: sessionsForDay.map((session) {
                              return ListTile(
                                leading: const Icon(Icons.book),
                                title: Text(session.topic.topic),
                                subtitle: Text(
                                  '${session.unitName} - ${_formatTime(session.allocatedTimeMinutes)}',
                                ),
                                trailing: Column(
                                  // Use Column for multiple trailing texts
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Imp: ${session.topic.importance}'),
                                    Text('Diff: ${session.topic.difficulty}'),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
