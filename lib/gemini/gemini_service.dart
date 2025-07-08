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

    final prompt =
        """
You are an expert assistant for analyzing academic syllabus text extracted using OCR.

Your tasks:

1.  First, detect if the input text is an academic syllabus.
    -   If it is **not a syllabus**, return the following JSON **exactly**:

        ```json
        {
          "is_syllabus": false,
          "message": "NOT_SYLLABUS"
        }
        ```

2.  If the input is a syllabus, follow these rules:

    ➤ **STRUCTURE:**
    Extract all units, topics, and subtopics hierarchically.
    Subtopics may be nested to multiple levels (child, grandchild, etc.).
    If unit titles like "Unit I", "Unit II" are missing, detect and create logical unit groups using section breaks, numbering, or headers.

    ➤ **For each topic and subtopic, include:**
    "topic": the actual name (no placeholder like [Topic Name])
    "estimated_time": in minutes (default: 15 if uncertain. If not explicitly stated, infer a reasonable time based on the topic's perceived depth, breadth, and typical academic coverage, relative to other topics in the unit. Aim for realistic, varied estimates where appropriate.)
    "importance": value between 1 to 5 (default: 3)
    "difficulty": 1 (easy) to 5 (very hard) (default: 3 if uncertain. If not explicitly stated, infer based on the inherent complexity of the subject matter, prerequisites, or common understanding of the topic's challenge level in an academic context.)
    "resources": a list of free resources, preferably links (PDFs or websites). If not available, use an empty list: [].

    ➤ **Hierarchy Detection Rules:**
    Prioritize visual structure (indentation, bullets, numbered lists, distinct line breaks) *above all else* for determining subtopic hierarchy and depth.
    If comma-separated concepts are found within a single line under a topic, and they represent *clearly distinct and separable ideas or sub-sections*, *always* split them as individual child subtopics. Do not club multiple distinct concepts into a single 'topic' node if they are logically separate. **Err on the side of disaggregating content into more granular topics/subtopics when ambiguity arises, rather than clumping them.**
    Nest subtopics logically under their parents, and allow for multiple levels of nesting as indicated by the text structure.
    Avoid using placeholder names like "[Subtopic Title]" — always use real titles from the syllabus.

    ➤ **JSON Response Format:**

    ```json
    {
      "is_syllabus": true,
      "total_estimated_time_for_syllabus": 0,
      "units": [
        {
          "unit_name": "Unit I: [Actual Unit Title]",
          "total_estimated_time": 0,
          "topics": [
            {
              "topic": "[Actual Topic Title]",
              "estimated_time": 45,
              "importance": 3,
              "difficulty": 2,
              "resources": [],
              "subtopics": [
                {
                  "topic": "[Actual Subtopic]",
                  "estimated_time": 30,
                  "importance": 3,
                  "difficulty": 2,
                  "resources": [],
                  "subtopics": [
                    {
                      "topic": "[Grandchild Subtopic]",
                      "estimated_time": 20,
                      "importance": 3,
                      "difficulty": 2,
                      "resources": []
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
    ```
    Set total_estimated_time for each unit as the sum of estimated_time of all nested topics and subtopics.
    Set total_estimated_time_for_syllabus as the sum of all unit times.

    Finally, output only the JSON — no explanation, no comments, no extra text.

Here is the syllabus:
$syllabusText
""";

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
      // print(jsonResponse);
      return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('Gemini API Error: ${response.body}');
    }
  }
}
