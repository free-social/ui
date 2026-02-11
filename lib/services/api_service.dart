import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../main.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path.contains('/auth/login')) {
            // Don’t attach old token
            return handler.next(options);
          }
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        onError: (DioException e, handler) async {
          print("API Error: ${e.response?.statusCode}");

          if (e.response?.statusCode == 401) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear(); // clear old token + user data

            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              'auth/login',
              (route) => false,
            );
          }

          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;
}
