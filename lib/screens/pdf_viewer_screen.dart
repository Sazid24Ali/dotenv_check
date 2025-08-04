// lib/screens/pdf_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // FIX: Ensure this import is present and correct
import 'dart:io';

import 'package:open_file/open_file.dart';

import 'package:path_provider/path_provider.dart'; // For File operations

class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String title;

  const PdfViewerScreen(
      {super.key, required this.pdfPath, required this.title});

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
      if (mounted) {
        // Check if widget is still in tree before showing UI feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error: PDF file not found at ${widget.pdfPath.split('/').last}!')),
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

  // Future<void> savePdfToDevice(List<int> pdfBytes, String fileName) async {
  //   final directory = await getExternalStorageDirectory();
  //   final path = directory?.path;
  //   if (path != null) {
  //     final file = File('$path/$fileName');
  //     await file.writeAsBytes(pdfBytes, flush: true);
  //     print('Saved PDF to $path/$fileName');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
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
                });
              },
              onError: (error) {
                print('PDFView Error: ${error.toString()}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error loading PDF: ${error.toString()}')),
                );
                setState(() {
                  _isLoading = false;
                });
              },
              onPageError: (page, error) {
                print('PDFView Page Error: $page: ${error.toString()}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Error on page $page: ${error.toString()}')),
                );
              },
              onViewCreated: (PDFViewController pdfViewController) {
                _pdfViewController = pdfViewController;
              },
              onPageChanged: (int? page, int? total) {
                setState(() {
                  _currentPage = page ?? 0;
                });
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pages >= 2 && !_isLoading)
            FloatingActionButton(
              heroTag: "toggle_button",
              onPressed: () {
                if (_pdfViewController != null) {
                  _pdfViewController!
                      .setPage(_currentPage == 0 ? _pages - 1 : 0);
                }
              },
              child: const Icon(Icons.swap_vert),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "save_button",
            onPressed: () async {
              try {
                final sourceFile = File(widget.pdfPath);
                final docsDir = await getExternalStorageDirectory();
                final fileName = sourceFile.uri.pathSegments.last;
                final targetPath = '${docsDir?.path}/$fileName';
                await sourceFile.copy(targetPath);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PDF saved to $targetPath')),
                );
                final result = await OpenFile.open(targetPath);
                print('OpenFile result: ${result.type}');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving PDF: $e')),
                );
              }
            },
            child: const Icon(Icons.save),
          ),
        ],
      ),
    );
  }
}
