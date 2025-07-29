// lib/utils/pdf_generator.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
// REMOVED: import 'package:open_filex/open_filex.dart'; // No longer opening externally

import '../models/syllabus_analyzer_models.dart';
// For formatting time

class PdfGenerator {
  static Future<String> generateSyllabusPdf(SyllabusAnalysisResponse syllabus) async { // Changed return type to Future<String>
    final pdf = pw.Document();

    // Helper to format time (similar to what's in TopicEditorScreen)
    String formatTime(int minutes) {
      if (minutes < 0) return "N/A";
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (h > 0 && m > 0) return "${h}h ${m}m";
      if (h > 0) return "${h}h";
      return "${m}m";
    }

    // Add content to the PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                syllabus.courseTitle.isNotEmpty ? syllabus.courseTitle : 'Syllabus Analysis',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (syllabus.courseCode.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  syllabus.courseCode,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            pw.SizedBox(height: 20),
            pw.Text('Instructor: ${syllabus.instructor.isNotEmpty ? syllabus.instructor : 'N/A'}'),
            pw.Text('Semester: ${syllabus.semester.isNotEmpty ? syllabus.semester : 'N/A'}${syllabus.year != null && syllabus.year! > 0 ? ' ${syllabus.year}' : ''}'),
            pw.Text('Total Estimated Study Time: ${formatTime(syllabus.totalEstimatedTimeForSyllabus)}'),
            pw.SizedBox(height: 20),

            if (syllabus.learningObjectives.isNotEmpty) ...[
              pw.Text('Learning Objectives:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: syllabus.learningObjectives
                    .map((obj) => pw.Text('• $obj'))
                    .toList(),
              ),
              pw.SizedBox(height: 10),
            ],

            if (syllabus.gradingBreakdown.isNotEmpty) ...[
              pw.Text('Grading Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: syllabus.gradingBreakdown.entries
                    .map((entry) => pw.Text('${entry.key}: ${entry.value}'))
                    .toList(),
              ),
              pw.SizedBox(height: 10),
            ],

            if (syllabus.requiredMaterials.isNotEmpty) ...[
              pw.Text('Required Materials:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: syllabus.requiredMaterials
                    .map((mat) => pw.Text('• $mat'))
                    .toList(),
              ),
              pw.SizedBox(height: 10),
            ],

            if (syllabus.importantDates.isNotEmpty) ...[
              pw.Text('Important Dates:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: syllabus.importantDates
                    .map((dateEntry) => pw.Text('${dateEntry.event}: ${dateEntry.date}'))
                    .toList(),
              ),
              pw.SizedBox(height: 10),
            ],

            if (syllabus.contactInformation != null) ...[
              pw.Text('Contact Information:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (syllabus.contactInformation!.email.isNotEmpty)
                pw.Text('Email: ${syllabus.contactInformation!.email}'),
              if (syllabus.contactInformation!.officeHours.isNotEmpty)
                pw.Text('Office Hours: ${syllabus.contactInformation!.officeHours}'),
              if (syllabus.contactInformation!.otherDetails.isNotEmpty)
                pw.Text('Other Details: ${syllabus.contactInformation!.otherDetails}'),
              pw.SizedBox(height: 10),
            ],

            pw.Divider(),
            pw.SizedBox(height: 10),

            pw.Text('Weekly Schedule / Topics:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Recursively build topics
            ..._buildTopicPdfWidgets(syllabus.units.map((u) => Topic(topic: u.unitName, estimatedTime: u.totalEstimatedTime, subtopics: u.topics)).toList(), formatTime, level: 0),
          ];
        },
      ),
    );

    // Get the directory for saving the PDF (app's internal documents directory)
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${syllabus.courseTitle.replaceAll(' ', '_').replaceAll('/', '_')}_Syllabus_Analysis.pdf';
    final file = File('${directory.path}/$fileName');

    // Save the PDF
    await file.writeAsBytes(await pdf.save());

    print('PDF saved to: ${file.path}');
    return file.path; // Return the path
  }

  // Helper function to build PDF widgets recursively for topics/subtopics
  static List<pw.Widget> _buildTopicPdfWidgets(
    List<Topic> topics,
    String Function(int) formatTime, {
    int level = 0,
  }) {
    List<pw.Widget> widgets = [];
    final double indent = level * 10.0; // Indentation for subtopics

    for (var topic in topics) {
      widgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(left: indent),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${'  ' * level}• ${topic.topic} (${formatTime(topic.estimatedTime)})',
                style: pw.TextStyle(fontWeight: level == 0 ? pw.FontWeight.bold : pw.FontWeight.normal),
              ),
              if (topic.importance != 3 || topic.difficulty != 3) // Only show if not default
                pw.Text(
                  '${'  ' * (level + 1)}Importance: ${topic.importance}, Difficulty: ${topic.difficulty}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (topic.timeReasoning.isNotEmpty)
                pw.Text(
                  '${'  ' * (level + 1)}Reasoning: ${topic.timeReasoning}',
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                ),
              if (topic.resources.isNotEmpty)
                pw.Text(
                  '${'  ' * (level + 1)}Resources: ${topic.resources.join(', ')}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              // Recursively add subtopics
              ..._buildTopicPdfWidgets(topic.subtopics, formatTime, level: level + 1),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}