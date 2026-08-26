import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  // 1. Resume Gap & Career Fit Scan
  static Future<Map<String, dynamic>> analyzeResume({
    required String targetRole,
    required PlatformFile file,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/analyze');
    final request = http.MultipartRequest('POST', uri);
    request.fields['target_role'] = targetRole;

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 35),
      onTimeout: () => throw Exception('Resume analysis request timed out.'),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to analyze resume (${response.statusCode}): ${response.body}');
    }
  }

  // 2. Live Market Intelligence Radar
  static Future<Map<String, dynamic>> getMarketRadar({
    required String targetRole,
    required String experienceLevel,
    required String location,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/market-radar');
    print('[FLUTTER] Fetching market data from: $uri');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'target_role': targetRole,
        'experience_level': experienceLevel,
        'location': location,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Market radar request timed out.'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Server error (${response.statusCode}): ${response.body}');
    }
  }

  // 3. Mock Interview Question Generator
  static Future<Map<String, dynamic>> getMockQuestions(
    String targetRole, [
    String experienceLevel = 'Intermediate',
  ]) async {
    final uri = Uri.parse('$baseUrl/api/v1/interview/questions');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'target_role': targetRole,
        'experience_level': experienceLevel,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch questions (${response.statusCode}): ${response.body}');
    }
  }

  // 4. Mock Interview Answer Evaluator
  static Future<Map<String, dynamic>> evaluateAnswer({
    required String question,
    required String userAnswer,
    required String targetRole,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/interview/evaluate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'question': question,
        'user_answer': userAnswer,
        'target_role': targetRole,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to evaluate answer (${response.statusCode}): ${response.body}');
    }
  }

  // 5. ATS Resume Optimizer
  static Future<Map<String, dynamic>> tailorResume({
    required String resumeText,
    required String jobDescription,
    required String targetRole,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/ats/tailor');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'resume_text': resumeText,
        'job_description': jobDescription,
        'target_role': targetRole,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to optimize resume (${response.statusCode}): ${response.body}');
    }
  }
}