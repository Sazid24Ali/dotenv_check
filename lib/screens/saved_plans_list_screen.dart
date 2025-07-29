// lib/screens/saved_plans_list_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/study_plan_models.dart'; // Import your StudyPlan model
import 'study_plan_display_screen.dart'; // Import the screen to display a plan

class SavedPlansListScreen extends StatefulWidget {
  const SavedPlansListScreen({super.key});

  @override
  State<SavedPlansListScreen> createState() => _SavedPlansListScreenState();
}

class _SavedPlansListScreenState extends State<SavedPlansListScreen> {
  List<Map<String, dynamic>> _savedPlansRaw =
      []; // List to hold raw saved plan data
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPlans();
  }

  Future<void> _loadSavedPlans() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedPlansJson = prefs.getString('saved_study_plans');
      if (savedPlansJson != null) {
        final List<dynamic> decodedList = json.decode(savedPlansJson);
        setState(() {
          _savedPlansRaw = decodedList
              .map((item) => item as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (e) {
      print('Error loading saved study plans: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading saved plans: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePlan(int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text(
          'Are you sure you want to delete "${_savedPlansRaw[index]['planTitle']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _savedPlansRaw.removeAt(index);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_study_plans', json.encode(_savedPlansRaw));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan deleted successfully.')),
      );
    }
  }

  void _openPlan(Map<String, dynamic> planData) {
    try {
      final StudyPlan loadedPlan = StudyPlan.fromJson(planData['planData']);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudyPlanDisplayScreen(plan: loadedPlan),
        ),
      );
    } catch (e) {
      print('Error parsing saved plan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening plan: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Saved Study Plans'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedPlans,
            tooltip: 'Refresh Plans',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedPlansRaw.isEmpty
          ? const Center(child: Text('No saved study plans found.'))
          : ListView.builder(
              itemCount: _savedPlansRaw.length,
              itemBuilder: (context, index) {
                final planEntry = _savedPlansRaw[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  elevation: 2,
                  child: ListTile(
                    title: Text(planEntry['planTitle'] ?? 'Unnamed Plan'),
                    subtitle: Text(
                      'Saved: ${planEntry['timestamp'] != null ? DateTime.parse(planEntry['timestamp']).toLocal().toString().substring(0, 16) : 'N/A'}',
                    ),
                    onTap: () => _openPlan(planEntry),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePlan(index),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
