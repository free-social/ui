import 'package:dio/dio.dart';
import 'api_service.dart';

class AiService {
  final ApiService _apiService;

  AiService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  Future<String> sendMessage(String content, List<Map<String, dynamic>> history) async {
    try {
      final response = await _apiService.client.post(
        '/chat/ai',
        data: {
          'content': content,
          'history': history,
        },
      );
      return response.data['data']['text'] as String;
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          throw Exception(data['error']);
        }
      }
      throw Exception('Failed to communicate with AI');
    }
  }
}
