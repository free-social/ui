import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http_parser/http_parser.dart'; // Required for MediaType
import 'dart:io'; // Required for File
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;

  // ✅ Constructor Injection
  AuthService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // --- NEW: UPDATE USERNAME (PUT) ---
  // Route: {{expense_url}}/auth/:id
  Future<Map<String, dynamic>> updateUsername(
    String userId,
    String newUsername,
  ) async {
    try {
      final response = await _apiService.client.put(
        '/auth/$userId',
        data: {"username": newUsername},
      );
      print('Username update successful: ${response.data}');
      return response.data; //
    } catch (e) {
      _handleError(e, 'Failed to update username');
      return {};
    }
  }

  // --- NEW: UPLOAD AVATAR (POST MULTIPART) ---
  // Route: {{expense_url}}/auth/:id/avatar
  Future<Map<String, dynamic>> uploadAvatar(
    String userId,
    File imageFile,
  ) async {
    try {
      String fileName = imageFile.path.split('/').last;

      // Prepare Multipart data matching your Postman 'avatars' key
      FormData formData = FormData.fromMap({
        "avatars": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          contentType: MediaType(
            "image",
            "jpg",
          ), // Adjust based on your file type
        ),
      });

      final response = await _apiService.client.post(
        '/auth/$userId/avatar',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ), // Ensure multipart header
      );

      print('Avatar upload successful: ${response.data}');
      return response.data; //
    } catch (e) {
      _handleError(e, 'Failed to upload avatar');
      return {};
    }
  }

  // --- EXISTING METHODS ---
  // lib/services/auth_service.dart

  // ✅ Fetches the dynamic user data from the database
  Future<Map<String, dynamic>> getProfile(String userId) async {
    try {
      // Route matching your new Postman request
      final response = await _apiService.client.get('/auth/$userId/profile');

      print('Profile retrieved successfully: ${response.data}');
      return response.data;
    } catch (e) {
      _handleError(e, 'Failed to retrieve user profile');
      return {};
    }
  }

  Future<void> register(String username, String email, String password) async {
    try {
      final response = await _apiService.client.post(
        '/auth/register',
        data: {"username": username, "email": email, "password": password},
      );
      print('Registration successful: ${response.data}');
    } catch (e) {
      _handleError(e, 'Failed to register');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // 0️⃣ Clear old token + userId before login
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('userId');

      // ✅ Clear in-memory cached user data if you have any
      // Example: UserController.instance.clearUserData();
      // Otherwise, homepage might show old or empty data

      // 1️⃣ Make login request
      final response = await _apiService.client.post(
        '/auth/login',
        data: {"email": email, "password": password},
      );

      final data = response.data;
      final token = data['token'];

      // 2️⃣ Extract User ID
      final userId = data['user']['id'] ?? data['user']['_id'];

      // 3️⃣ Save new token + userId to SharedPreferences
      if (token != null) await prefs.setString('token', token);
      if (userId != null) await prefs.setString('userId', userId);

      return data;
    } catch (e) {
      _handleError(e, 'Login failed');
      return {};
    }
  }

  Future<String> googleAuth() async {
    try {
      final baseUrl = _apiService.client.options.baseUrl;
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      // Ensure your backend route is correct
      final url = '$cleanBaseUrl/auth/google';
      const callbackUrlScheme = 'spendwise';

      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
      );

      // ✅ 1. Parse BOTH Token and User ID from the URL
      final queryParams = Uri.parse(result).queryParameters;
      final token = queryParams['token'];

      // Check for 'id', 'userId', or '_id' depending on what your backend sends
      final userId =
          queryParams['userId'] ?? queryParams['id'] ?? queryParams['_id'];

      if (token == null) throw Exception('No token found in Google callback');

      // ✅ 2. Save BOTH to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      if (userId != null) {
        await prefs.setString('userId', userId);
      }

      return token;
    } catch (e) {
      _handleError(e, 'Google login failed');
      return '';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void _handleError(dynamic e, String defaultMessage) {
    print('Error: $e');
    String errorMessage = defaultMessage;
    if (e is DioException) {
      if (e.response?.data != null) {
        final responseData = e.response!.data;
        if (responseData is Map && responseData.containsKey('error')) {
          errorMessage = responseData['error'];
        }
      }
    }
    throw Exception(errorMessage);
  }
}
