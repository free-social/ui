
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart'; // ✅ Import your new file

class ApiService {
  // ✅ Use the variable from constants.dart
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        // Debugging logs
        print("🌍 Request to: ${options.baseUrl}${options.path}");
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print("❌ API Error: ${e.response?.statusCode}");
        return handler.next(e);
      },
    ));
  }

  Dio get client => _dio;
}