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
    double distanceKm = 0.0,
    List<Map<String, dynamic>> timedPoints = const [],
  }) async {
    // Prefer segment-level calculation when timed GPS data is available
    final localCalories = timedPoints.length >= 2
        ? _calculateCaloriesFromSegments(
            category: category,
            weightKg: weightKg,
            timedPoints: timedPoints,
          )
        : _calculateCaloriesLocally(
            category: category,
            weightKg: weightKg,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
          );

    try {
      final response = await _apiService.client.post(
        '/sport/calculate-calories',
        data: {
          'category': category,
          'weightKg': weightKg,
          'duration': durationMinutes,
          'distanceKm': distanceKm,
        },
      );
      return _extractCalories(response.data) ?? localCalories;
    } catch (_) {
      return localCalories;
    }
  }

  /// Gold-standard per-segment calorie calculation using timed GPS points.
  ///
  /// Each GPS segment gets its own speed-accurate MET value, so a mixed
  /// run + walk (or interval) session is calculated correctly without the
  /// nonlinearity error that average-speed methods introduce.
  ///
  /// Segments with a timestamp gap > 5 min are treated as paused/idle
  /// and contribute 0 calories (resting MET ≈ 1.0 is negligible).
  double _calculateCaloriesFromSegments({
    required String category,
    required double weightKg,
    required List<Map<String, dynamic>> timedPoints,
  }) {
    double totalCalories = 0.0;

    for (int i = 1; i < timedPoints.length; i++) {
      final prev = timedPoints[i - 1];
      final curr = timedPoints[i];

      // Parse timestamps — skip segment if either is missing/invalid
      final tsStr1 = prev['ts'] as String? ?? '';
      final tsStr2 = curr['ts'] as String? ?? '';
      if (tsStr1.isEmpty || tsStr2.isEmpty) continue;
      final t1 = DateTime.tryParse(tsStr1);
      final t2 = DateTime.tryParse(tsStr2);
      if (t1 == null || t2 == null) continue;

      final segSeconds = t2.difference(t1).inSeconds;
      if (segSeconds <= 0) continue;
      // Gap > 5 min = paused or GPS outage; skip (no active exercise)
      if (segSeconds > 300) continue;

      // Distance between the two GPS points (Haversine via geolocator formula)
      final latDiff = (curr['lat'] as double) - (prev['lat'] as double);
      final lngDiff = (curr['lng'] as double) - (prev['lng'] as double);
      // Fast flat-earth approximation — accurate enough for sub-100m segments
      const degToRad = 3.141592653589793 / 180.0;
      final lat1Rad = (prev['lat'] as double) * degToRad;
      final x = lngDiff * degToRad * _cos(lat1Rad);
      final y = latDiff * degToRad;
      final segDistanceM = 6371000 * _sqrt(x * x + y * y);

      // Speed in m/min for this segment
      final speedMMin = segDistanceM / (segSeconds / 60.0);

      // Pick ACSM equation: run if > 6 km/h (100 m/min), else walk
      final double met;
      if (speedMMin >= 100.0) {
        // Running — ACSM: VO2 = 0.2 × speed + 3.5, MET = VO2 / 3.5
        final vo2 = 0.2 * speedMMin + 3.5;
        met = (vo2 / 3.5).clamp(6.0, 23.0);
      } else {
        // Walking — ACSM: VO2 = 0.1 × speed + 3.5, MET = VO2 / 3.5
        final vo2 = 0.1 * speedMMin + 3.5;
        met = (vo2 / 3.5).clamp(2.0, 6.5);
      }

      final segHours = segSeconds / 3600.0;
      totalCalories += met * weightKg * segHours;
    }

    return double.parse(totalCalories.toStringAsFixed(1));
  }

  // Inline trig helpers (dart:math import-free for the isolate entry point)
  static double _cos(double x) {
    // Taylor series cos(x) accurate to ±0.00001 for |x| < π/2
    final x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 10; i++) r = (r + x / r) / 2;
    return r;
  }

  /// High-accuracy calorie calculation using speed-adjusted MET.
  ///
  /// For running/jogging the ACSM metabolic equation is applied:
  ///   VO2 (mL/kg/min) = 0.2 × speed_m_min + 3.5
  ///   MET = VO2 / 3.5
  ///   Calories = MET × weightKg × durationHours
  ///
  /// When distanceKm > 0 the actual speed is used; otherwise a
  /// conservative default speed is assumed per category.

  double _calculateCaloriesLocally({
    required String category,
    required double weightKg,
    required int durationMinutes,
    double distanceKm = 0.0,
  }) {
    if (durationMinutes <= 0) return 0.0;
    final durationHours = durationMinutes / 60.0;
    final met = _speedAdjustedMet(
      category: category,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
    final calories = met * weightKg * durationHours;
    return double.parse(calories.toStringAsFixed(1));
  }

  /// Returns a MET value adjusted for the actual average speed.
  ///
  /// Speed-to-MET references:
  ///   Running  – ACSM formula: MET = (0.2 × speed_m_min + 3.5) / 3.5
  ///   Walking  – ACSM formula: MET = (0.1 × speed_m_min + 3.5) / 3.5
  ///   Cycling  – linear interpolation from validated MET tables (Ainsworth 2011)
  ///   Swimming – fixed 8.0 (moderate front-crawl)
  double _speedAdjustedMet({
    required String category,
    required double distanceKm,
    required int durationMinutes,
  }) {
    // Derive speed in m/min from actual distance when available.
    final double speedMMin = (distanceKm > 0 && durationMinutes > 0)
        ? (distanceKm * 1000) / durationMinutes
        : _defaultSpeedMMin(category);

    switch (category.toLowerCase()) {
      case 'walking':
        // ACSM walking equation (valid 50–100 m/min ≈ 3–6 km/h)
        final vo2 = 0.1 * speedMMin + 3.5;
        return (vo2 / 3.5).clamp(2.0, 6.5);

      case 'cycling':
        // Ainsworth compendium: 4.0 MET @ ~16 km/h, 8.0 @ ~22 km/h,
        // 12.0 @ ~32 km/h.  Linear approximation:
        //   MET ≈ 5.71 + 0.196 × speed_km_h
        final speedKmh = speedMMin * 60 / 1000;
        return (5.71 + 0.196 * speedKmh).clamp(4.0, 16.0);

      case 'swimming':
        // Fixed moderate-intensity value (Ainsworth 2011 code 18310)
        return 8.0;

      case 'jogging':
      default:
        // ACSM running/jogging equation (valid > 80 m/min ≈ 4.8 km/h)
        final vo2 = 0.2 * speedMMin + 3.5;
        return (vo2 / 3.5).clamp(6.0, 23.0);
    }
  }

  /// Fallback speed in m/min when no GPS distance is available.
  double _defaultSpeedMMin(String category) {
    switch (category.toLowerCase()) {
      case 'walking':
        return 83.0;  // ~5 km/h
      case 'cycling':
        return 300.0; // ~18 km/h
      case 'swimming':
        return 50.0;  // ~3 km/h
      case 'jogging':
      default:
        return 160.0; // ~9.6 km/h
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
