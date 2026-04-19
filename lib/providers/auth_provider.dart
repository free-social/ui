import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/local_cache_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final LocalCacheService _cacheService;

  // Constructor Injection
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService(),
      _cacheService = LocalCacheService();

  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  // RESTART LOGIC: Works because AuthService saved the userId
  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token != null && userId != null) {
      _isAuthenticated = true;
      _user = await _cacheService.getUserProfile(userId);
      notifyListeners();
      try {
        final responseData = await _authService.getProfile(userId);
        if (responseData.containsKey('user')) {
          _user = User.fromJson(responseData['user']);
          await _cacheService.saveUserProfile(userId, _user!);
        }
      } catch (e) {
        // Profile sync failed, continue with cached auth state
      }
      notifyListeners();
    }
  }

  // --- UPDATE USERNAME ---
  Future<void> updateUsername(String userId, String newUsername) async {
    _setLoading(true);
    try {
      await _authService.updateUsername(userId, newUsername);
      if (_user != null) {
        _user = _user!.copyWith(username: newUsername);
        await _cacheService.saveUserProfile(userId, _user!);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- UPLOAD AVATAR ---
  Future<void> uploadAvatar(String userId, File imageFile) async {
    _setLoading(true);
    try {
      final response = await _authService.uploadAvatar(userId, imageFile);
      if (response.containsKey('user') &&
          response['user'].containsKey('avatar')) {
        final String newAvatarUrl = response['user']['avatar'];
        if (_user != null) {
          _user = _user!.copyWith(avatar: newAvatarUrl);
          await _cacheService.saveUserProfile(userId, _user!);
        }
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- AUTH METHODS ---

  // LOGIN LOGIC: Fetches profile after successful authentication
  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      // Step A: Login (Get Token & ID)
      final responseData = await _authService.login(email, password);

      // Step B: Extract ID
      final userId = responseData['user']['id'] ?? responseData['user']['_id'];

      // Step C: Fetch full profile immediately
      // This ensures we get the avatar even if the login API forgot to send it.
      if (userId != null) {
        try {
          final profileData = await _authService.getProfile(userId);
          if (profileData.containsKey('user')) {
            _user = User.fromJson(profileData['user']);
            await _cacheService.saveUserProfile(userId, _user!);
          }
        } catch (e) {
          // If profile fetch fails, fall back to basic login data
          if (responseData.containsKey('user')) {
            _user = User.fromJson(responseData['user']);
            await _cacheService.saveUserProfile(userId, _user!);
          }
        }
      }

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(String username, String email, String password) async {
    _setLoading(true);
    try {
      await _authService.register(username, email, password);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> forgotPassword(String email) async {
    _setLoading(true);
    try {
      return await _authService.forgotPassword(email);
    } finally {
      _setLoading(false);
    }
  }

  Future<String> resetPassword(
    String email,
    String otp,
    String password,
  ) async {
    _setLoading(true);
    try {
      return await _authService.resetPassword(email, otp, password);
    } finally {
      _setLoading(false);
    }
  }

  Future<String> updatePassword(
    String userId,
    String currentPassword,
    String newPassword,
  ) async {
    _setLoading(true);
    try {
      final message = await _authService.updatePassword(
        userId,
        currentPassword,
        newPassword,
      );
      await _cacheService.clearUserProfile(userId);
      _user = null;
      _isAuthenticated = false;
      notifyListeners();
      return message;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> googleLogin() async {
    _setLoading(true);
    try {
      await _authService.googleAuth();

      await checkAuthStatus();

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    final userId = _user?.id;
    await _authService.logout();
    if (userId != null && userId.isNotEmpty) {
      await _cacheService.clearUserProfile(userId);
      await _cacheService.clearWalletData(userId);
      await _cacheService.clearTransactionCaches(userId);
    }
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
