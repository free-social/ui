import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/navigation/app_navigator.dart';
import '../utils/constants.dart';
import '../utils/snackbar_helper.dart';
import 'push_notification_service.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (kDebugMode) {
            debugPrint('[API] ${options.method} ${options.uri}');
          }

          final prefs = await SharedPreferences.getInstance();
          final pushToken = prefs.getString('pushToken');
          final deviceId = await PushNotificationService.instance
              .getOrCreateDeviceId();
          options.headers['X-Device-Id'] = deviceId;
          options.headers['X-Device-Platform'] =
              PushNotificationService.instance.platformHeaderValue;
          options.headers['X-Device-Name'] =
              PushNotificationService.instance.deviceName;
          if (pushToken != null && pushToken.trim().isNotEmpty) {
            options.headers['X-Push-Token'] = pushToken.trim();
          }

          if (options.path.contains('/auth/login')) {
            // Don’t attach old token
            return handler.next(options);
          }
          final token = prefs.getString('token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '[API] ${response.statusCode} '
              '${response.requestOptions.method} '
              '${response.requestOptions.uri}',
            );
          }
          return handler.next(response);
        },

        onError: (DioException e, handler) async {
          if (kDebugMode) {
            debugPrint(
              '[API][ERROR] ${e.response?.statusCode ?? e.type.name} '
              '${e.requestOptions.method} '
              '${e.requestOptions.uri}',
            );
            if (e.response?.data != null) {
              debugPrint('[API][ERROR][BODY] ${e.response?.data}');
            } else if (e.message != null) {
              debugPrint('[API][ERROR][MESSAGE] ${e.message}');
            }
          }

          final errorMessage = (e.message ?? '').toLowerCase();

          if (e.type == DioExceptionType.badCertificate ||
              errorMessage.contains('cert') ||
              errorMessage.contains('handshake')) {
            final context = navigatorKey.currentContext;
            if (context != null) {
              showErrorSnackBar(
                context,
                'Secure connection failed. Check device time or certificate trust.',
              );
            }
          }

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
            final pushToken = prefs.getString('pushToken');
            final deviceId = prefs.getString('deviceId');
            await prefs.clear(); // clear old token + user data
            if (pushToken != null && pushToken.trim().isNotEmpty) {
              await prefs.setString('pushToken', pushToken);
            }
            if (deviceId != null && deviceId.trim().isNotEmpty) {
              await prefs.setString('deviceId', deviceId);
            }

            final navigator = navigatorKey.currentState;
            if (navigator != null) {
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
            }
          }

          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;
}
