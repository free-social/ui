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
      final payload = sport.toJson();
      final response = await _apiService.client.post('/sport', data: payload);
      return SportModel.fromJson(response.data);
    } catch (e) {
      // Backward-compatible retry in case backend schema does not accept
      // newly added optional fields yet.
      if (sport.calories != null) {
        try {
          final legacyPayload = sport.toJson()..remove('calories');
          final response = await _apiService.client.post(
            '/sport',
            data: legacyPayload,
          );
          return SportModel.fromJson(response.data);
        } catch (_) {}
      }
      throw Exception('Failed to create sport entry: $e');
    }
  }

  Future<double> calculateCalories({
    required String category,
    required double weightKg,
    required int durationMinutes,
  }) async {
    final localCalories = _calculateCaloriesLocally(
      category: category,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
    );

    try {
      final response = await _apiService.client.post(
        '/sport/calculate-calories',
        data: {
          'category': category,
          'weightKg': weightKg,
          'duration': durationMinutes,
        },
      );
      return _extractCalories(response.data) ?? localCalories;
    } catch (_) {
      return localCalories;
    }
  }

  double _calculateCaloriesLocally({
    required String category,
    required double weightKg,
    required int durationMinutes,
  }) {
    final durationHours = durationMinutes <= 0 ? 0.0 : durationMinutes / 60.0;
    final met = _metByCategory(category);
    final calories = met * weightKg * durationHours;
    return double.parse(calories.toStringAsFixed(1));
  }

  double _metByCategory(String category) {
    switch (category.toLowerCase()) {
      case 'walking':
        return 4.3;
      case 'cycling':
        return 7.5;
      case 'swimming':
        return 8.0;
      case 'jogging':
      default:
        return 8.3;
    }
  }

  double? _extractCalories(dynamic data) {
    if (data is num) return data.toDouble();
    if (data is Map<String, dynamic>) {
      final direct = data['calories'] ?? data['kcal'];
      if (direct is num) return direct.toDouble();
      if (direct != null) return double.tryParse(direct.toString());

      final nested = data['data'];
      if (nested is Map<String, dynamic>) {
        final nestedCalories = nested['calories'] ?? nested['kcal'];
        if (nestedCalories is num) return nestedCalories.toDouble();
        if (nestedCalories != null) {
          return double.tryParse(nestedCalories.toString());
        }
      }
    }
    return null;
  }
}
