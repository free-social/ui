import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;

  // Constructor Injection
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

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
      try {
        final responseData = await _authService.getProfile(userId);
        if (responseData.containsKey('user')) {
          _user = User.fromJson(responseData['user']);
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
          }
        } catch (e) {
          // If profile fetch fails, fall back to basic login data
          if (responseData.containsKey('user')) {
            _user = User.fromJson(responseData['user']);
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
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
