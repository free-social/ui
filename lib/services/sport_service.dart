import '../models/sport_model.dart';

import 'api_service.dart';

class SportService {
  final ApiService _apiService;

  SportService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  Future<List<SportModel>> getSports({
    int page = 1,
    int limit = 10,
    String sortBy = 'date',
    String sortOrder = 'desc',
  }) async {
    try {
      final response = await _apiService.client.get(
        '/sport',
        queryParameters: {
          'page': page,
          'limit': limit,
          'sortBy': sortBy,
          'sortOrder': sortOrder,
        },
      );

      List<dynamic> data;
      if (response.data is Map && response.data.containsKey('docs')) {
        data = response.data['docs'];
      } else if (response.data is List) {
        data = response.data;
      } else {
        data = [];
      }

      return data.map((json) => SportModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load sports history: $e');
    }
  }

  Future<SportModel> getSport(String id) async {
    try {
      final response = await _apiService.client.get('/sport/$id');
      return SportModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get sport: $e');
    }
  }

  Future<SportModel> createSport(SportModel sport) async {
    try {
      final response = await _apiService.client.post(
        '/sport',
        data: sport.toJson(),
      );
      return SportModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create sport entry: $e');
    }
  }
}
