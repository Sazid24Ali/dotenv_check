// lib/screens/study_plan_display_screen.dart
import 'package:flutter/material.dart';
import '../models/study_plan_models.dart';

class StudyPlanDisplayScreen extends StatelessWidget {
  final StudyPlan plan;

  const StudyPlanDisplayScreen({super.key, required this.plan});

  // Helper to format time to hours and minutes
  String _formatTime(int minutes) {
    if (minutes < 0) return "N/A";
    final h = minutes ~/ 60;
    final m = minutes % 60;

    String hoursPart = '';
    String minutesPart = '';

    if (h > 0) {
      hoursPart = '${h}h';
    }
    if (m > 0) {
      minutesPart = '${m}m';
    }

    if (h == 0 && m == 0) return '0m'; // Handle case where time is 0

    return [hoursPart, minutesPart].where((s) => s.isNotEmpty).join(' ');
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

    int totalDaysInPlan = sortedDates.length;
    double averageMinutesPerDayInPlan = totalDaysInPlan > 0
        ? plan.sessions.fold(
                0,
                (sum, session) => sum + session.allocatedTimeMinutes,
              ) /
              totalDaysInPlan
        : 0;
    String averageHoursPerDayInPlan = (averageMinutesPerDayInPlan / 60)
        .toStringAsFixed(1);

    bool extendsBeyondDeadline = false;
    if (sortedDates.isNotEmpty) {
      final lastScheduledDate = sortedDates.last;
      if (lastScheduledDate.isAfter(plan.deadline)) {
        extendsBeyondDeadline = true;
      }
    }

    int totalScheduledTopicMinutes = plan.sessions
        .where((s) => !s.isRevision)
        .fold(0, (sum, session) => sum + session.allocatedTimeMinutes);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.planTitle),
            Text(
              'Target Deadline: ${plan.deadline.toLocal().year}-${plan.deadline.toLocal().month.toString().padLeft(2, '0')}-${plan.deadline.toLocal().day.toString().padLeft(2, '0')}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
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
              'Total Time Committed (by you until deadline): ${_formatTime(plan.totalAllocatedTimeMinutesUserCommitment)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Total Topics Scheduled: ${_formatTime(totalScheduledTopicMinutes)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Total Revision Scheduled: ${_formatTime(plan.totalRevisionTimeMinutes)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Total Days in Plan: $totalDaysInPlan days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Average Hours/Day (scheduled): $averageHoursPerDayInPlan hours',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (extendsBeyondDeadline)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Note: This plan extends beyond your target deadline to cover all material. Consider adjusting daily time or deadline.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (plan.uncoveredTopics.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uncovered Topics by Deadline (Please increase daily study or extend deadline):',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...plan.uncoveredTopics.map(
                      (topic) => Text(
                        '• ${topic.topic} (${_formatTime(topic.estimatedTime)} remaining)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
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

                        bool isPastDeadlineDay = date.isAfter(plan.deadline);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 3,
                          color: isPastDeadlineDay ? Colors.red.shade50 : null,
                          child: ExpansionTile(
                            title: Text(
                              '${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-${date.toLocal().day.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: isPastDeadlineDay
                                        ? Colors.red.shade800
                                        : null,
                                  ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total for day: ${_formatTime(totalTimeForDay)}',
                                ),
                                if (isPastDeadlineDay)
                                  Text(
                                    ' (Past Deadline)',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.red.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                              ],
                            ),
                            children: sessionsForDay.map((session) {
                              return ListTile(
                                leading: session.isRevision
                                    ? const Icon(
                                        Icons.refresh,
                                        color: Colors.blueGrey,
                                      )
                                    : const Icon(Icons.book),
                                title: Text(
                                  session.isRevision
                                      ? 'Revision Session'
                                      : session.topic?.topic ?? 'Unknown Topic',
                                ),
                                // Display scheduled start time
                                subtitle: Text(
                                  '${session.scheduledStartTime != null ? '${session.scheduledStartTime} - ' : ''}'
                                  '${session.unitName} - ${_formatTime(session.allocatedTimeMinutes)}',
                                ),
                                trailing: session.isRevision
                                    ? const Text('General Review')
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Imp: ${session.topic?.importance ?? '-'}',
                                          ),
                                          Text(
                                            'Diff: ${session.topic?.difficulty ?? '-'}',
                                          ),
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
