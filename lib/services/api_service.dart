import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Live Render backend URL
  static const String baseUrl = 'https://ai-careerpilot.onrender.com';

  static Future<Map<String, dynamic>> analyzeResume({
    required String targetRole,
    required dynamic file,
    String fileName = 'resume.pdf',
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/analyze');
    var request = http.MultipartRequest('POST', uri);
    request.fields['target_role'] = targetRole;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file,
        filename: fileName,
      ),
    );

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to analyze resume: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getMarketRadar({
    required String targetRole,
    required String experienceLevel,
    required String location,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/market-radar');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'target_role': targetRole,
        'experience_level': experienceLevel,
        'location': location,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch market intelligence: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> getMockQuestions(
    String targetRole,
    String experienceLevel,
  ) async {
    final uri = Uri.parse('$baseUrl/api/v1/interview/questions');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'target_role': targetRole,
        'experience_level': experienceLevel,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to generate interview questions: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> evaluateAnswer({
    required String question,
    required String userAnswer,
    required String targetRole,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/interview/evaluate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'question': question,
        'user_answer': userAnswer,
        'target_role': targetRole,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to evaluate answer: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> tailorResume({
    required String resumeText,
    required String jobDescription,
    required String targetRole,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/ats/tailor');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'resume_text': resumeText,
        'job_description': jobDescription,
        'target_role': targetRole,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to tailor resume bullets: ${response.body}');
    }
  }
}