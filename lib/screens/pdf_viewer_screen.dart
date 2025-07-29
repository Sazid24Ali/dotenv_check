// lib/screens/pdf_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // FIX: Ensure this import is present and correct
import 'dart:io'; // For File operations

class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String title;

  const PdfViewerScreen({super.key, required this.pdfPath, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  PDFViewController? _pdfViewController;
  int _pages = 0;
  int _currentPage = 0;
  // Removed _pdfReady as it's not strictly needed for basic loading feedback

  @override
  void initState() {
    super.initState();
    _checkFileAndLoadPdf();
  }

  void _checkFileAndLoadPdf() async {
    // It's crucial to check if the file actually exists before trying to load it
    final file = File(widget.pdfPath);
    if (!await file.exists()) {
      print('Error: PDF file does not exist at path: ${widget.pdfPath}');
      if (mounted) { // Check if widget is still in tree before showing UI feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: PDF file not found at ${widget.pdfPath.split('/').last}!')),
        );
        Navigator.pop(context); // Go back if file not found
      }
      return;
    }
    // If file exists, set loading to false as PDFView will handle its own loading state internally
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading // This _isLoading is for initial file existence check
          ? const Center(child: CircularProgressIndicator())
          : PDFView(
              filePath: widget.pdfPath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: false,
              pageFling: false,
              onRender: (int? pages) {
                setState(() {
                  _pages = pages ?? 0;
                  // _pdfReady = true; // No longer using _pdfReady state
                });
              },
              onError: (error) {
                print('PDFView Error: ${error.toString()}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error loading PDF: ${error.toString()}')),
                );
                setState(() {
                  _isLoading = false; // Indicate loading finished, even with error
                });
              },
              onPageError: (page, error) {
                print('PDFView Page Error: $page: ${error.toString()}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error on page $page: ${error.toString()}')),
                );
              },
              onViewCreated: (PDFViewController pdfViewController) {
                _pdfViewController = pdfViewController;
              },
              onPageChanged: (int? page, int? total) {
                setState(() {
                  _currentPage = page ?? 0; // Null-aware default to 0
                });
              },
            ),
      // Only show FloatingActionButton if PDF has multiple pages and is ready
      floatingActionButton: _pages >= 2 && !_isLoading
          ? FloatingActionButton(
              onPressed: () {
                if (_pdfViewController != null) {
                  // Toggle between first and last page for demonstration
                  _pdfViewController!.setPage(_currentPage == 0 ? _pages - 1 : 0);
                }
              },
              child: const Icon(Icons.swap_vert),
            )
          : null,
    );
  }
}