import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/study_plan_models.dart';
import '../utils/pdf_generator.dart';
import 'main_screen.dart';

class StudyPlanDisplayScreen extends StatefulWidget {
  final StudyPlan plan;

  const StudyPlanDisplayScreen({super.key, required this.plan});

  @override
  State<StudyPlanDisplayScreen> createState() => _StudyPlanDisplayScreenState();
}

class _StudyPlanDisplayScreenState extends State<StudyPlanDisplayScreen> {
  bool _isSaving = false;

  Future<void> _savePlan() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedPlans = prefs.getStringList('saved_plans') ?? [];

      // Use a unique name for each plan, e.g., by adding a timestamp.
      final planJson = jsonEncode(widget.plan.toJson());
      savedPlans.add(planJson);

      await prefs.setStringList('saved_plans', savedPlans);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan saved successfully!')),
      );

      // Navigate back to the main screen after saving.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save plan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _exportAsPdf() async {
    final result = await PdfGenerator.generateAndSavePdf(widget.plan);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.planName),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportAsPdf,
            tooltip: 'Export as PDF',
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _savePlan,
                  tooltip: 'Save Plan',
                ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.plan.dailySchedules.length,
        itemBuilder: (context, index) {
          final daySchedule = widget.plan.dailySchedules[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${daySchedule.day}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: IntrinsicColumnWidth(),
                      2: FlexColumnWidth(),
                    },
                    border: TableBorder.all(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                      style: BorderStyle.solid,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      _buildTableRow(['Start', 'End', 'Activity'],
                          isHeader: true),
                      ...daySchedule.timeSlots.map(
                        (slot) => _buildTableRow(
                          [slot.startTime, slot.endTime, slot.topic],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
    final style = isHeader
        ? TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : const TextStyle(fontSize: 14);
    return TableRow(
      decoration: isHeader
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            )
          : null,
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(cell, style: style),
        );
      }).toList(),
    );
  }
}
