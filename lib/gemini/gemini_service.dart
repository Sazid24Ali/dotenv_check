import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static Future<String> parseSyllabusWithGemini(String syllabusText) async {
    // ✅ Load the key safely at runtime
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    // https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`
    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey';

    //     final prompt =
    //         """
    // You are a syllabus parser. Given OCR text from a syllabus, extract:
    // - unit-wise structure
    // - topic names
    // - difficulty (1-5)
    // - estimated time in minutes (5–60)
    // - importance (default 3)
    // Return output strictly in JSON like:
    // {
    //   "units": [
    //     {
    //       "name": "Unit I: Introduction",
    //       "topics": [
    //         {
    //           "name": "History of AI",
    //           "difficulty": 3,
    //           "estimated_time": 15,
    //           "importance": 3
    //         }
    //       ]
    //     }
    //   ]
    // }
    // Text:
    // $syllabusText
    // """;
    //     final body = {
    //       "contents": [
    //         {
    //           "parts": [
    //             {"text": prompt},
    //           ],
    //         },
    //       ],
    //     };
    //     final prompt = """
    // You are a syllabus parser. Given OCR text from a syllabus, extract:
    // - unit-wise structure
    // - topic names
    // - difficulty (1-5)
    // - estimated time in minutes (5–60)
    // - importance (default 3)

    // Return only valid compact JSON (no explanations, no markdown).
    // """;
    final prompt =
        """
Parse this syllabus text into a structured JSON with multiple distinct units. 
Each unit must have:
- name (e.g., Unit I: Introduction to AI)
- topics (as list of topic objects)

Each topic should include:
- name
- difficulty (1–5)
- estimated_time (5–60)
- importance (default 3)

Output format:
{
  "units": [
    {
      "name": "Unit I: ...",
      "topics": [
        { "name": "Topic 1", "difficulty": 3, "estimated_time": 30, "importance": 3 }
      ]
    },
    ...
  ]
}

Here is the syllabus:
$syllabusText
""";
    // final body = {
    //   "contents": [
    //     {
    //       "parts": [
    //         {"text": "$prompt\nText:\n$syllabusText"},
    //       ],
    //     },
    //   ],
    // };
    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    };

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('Gemini API Error: ${response.body}');
    }
  }
}
