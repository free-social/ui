import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/snackbar_helper.dart';
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
          // Check for no internet connection
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.sendTimeout) {
            // Show no internet message at top
            final context = navigatorKey.currentContext;
            if (context != null) {
              showErrorSnackBar(context, 'No internet connection');
            }
          }

          // Handle 401 Unauthorized
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
